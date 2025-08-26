import pool from "../db.js";
import bcrypt from "bcrypt";

export const getUsers = async (req, res) => {
  try {
    const { rows } = await pool.query("SELECT * FROM users");
    res.json(rows);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      message: "Error al obtener usuarios",
    });
  }
};

export const getUserById = async (req, res) => {
  try {
    const { user_id } = req.params;
    const { rows } = await pool.query("SELECT * from users where id = $1", [
      user_id,
    ]);
    if (rows.length === 0) {
      return res.status(404).json({
        message: "Usuario no encontrado",
      });
    }
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).send("Error al obtener usuario por id");
  }
};

export const createUser = async (req, res) => {
  const { email, password, first_name, last_name, role, is_active } = req.body;
  const password_hash = await bcrypt.hash(password, 10);
  const { rows } = await pool.query(
    "INSERT INTO users (email, password_hash, first_name, last_name, role, is_active) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *",
    [email, password_hash, first_name, last_name, role, is_active]
  );
  res.json(rows[0]);
};

export const updateUser = async (req, res) => {
  try {
    const { user_id } = req.params;
    const { email, password, first_name, last_name, role, is_active } =
      req.body; // ← Extraer directamente

    // Validaciones
    if (!email || !first_name || !last_name || !role) {
      return res.status(400).json({
        error: "Email, first_name, last_name y role son obligatorios",
      });
    }

    // Si se envía password, hashearlo
    let password_hash = null;
    if (password) {
      password_hash = await bcrypt.hash(password, 10);
    }

    // Construir query dinámicamente
    let query, values;

    if (password_hash) {
      // Con password
      query = `
            UPDATE users 
            SET email = $1, password_hash = $2, first_name = $3, last_name = $4, role = $5, is_active = $6, updated_at = NOW()
            WHERE id = $7 
            RETURNING *
          `;
      values = [
        email,
        password_hash,
        first_name,
        last_name,
        role,
        is_active,
        user_id,
      ];
    } else {
      // Sin password
      query = `
            UPDATE users 
            SET email = $1, first_name = $2, last_name = $3, role = $4, is_active = $5, updated_at = NOW()
            WHERE id = $6 
            RETURNING *
          `;
      values = [email, first_name, last_name, role, is_active, user_id];
    }

    const { rows } = await pool.query(query, values);

    if (rows.length === 0) {
      return res.status(404).json({
        message: "Usuario no encontrado",
      });
    }

    res.json(rows[0]);
  } catch (error) {
    console.error("Error updating user:", error);
    res.status(500).json({ error: "Error interno del servidor" });
  }
};

export const deleteUser = async (req, res) => {
  const { user_id } = req.params;
  const { rows, rowCount } = await pool.query(
    "DELETE FROM users WHERE id = $1 RETURNING *",
    [user_id]
  );
  if (rowCount === 0) {
    return res.status(404).json({
      message: "Usuario no encontrado",
    });
  }
  return res.json({
    message: "Usuario eliminado correctamente",
    user: rows[0],
  });
};
