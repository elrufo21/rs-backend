import pg from "pg";

const pool = new pg.Pool({
    user: "postgres",
    host: "localhost",
    database: "r2",
    password: "75614167",
    port: 5432,
});




export default pool;