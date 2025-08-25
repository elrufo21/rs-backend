import { Router } from "express";

const router = Router();

router.get("/users", (req, res) => {
  res.send("Obtener usuarios");
});
router.get("/users/:user_id", (req, res) => {
  const { user_id } = req.params;
  res.send("Obtener usuario por id" + user_id);
});
router.post("/users", (req, res) => {
  res.send("creando usuario");
});
router.put("/users/:user_id", (req, res) => {
  const { user_id } = req.params;
  res.send("Actualizar usuario por id" + user_id);
});
router.delete("/users/:user_id", (req, res) => {
  const { user_id } = req.params;
  res.send("Eliminar usuario por id" + user_id);
});
export default router;
