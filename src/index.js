import express from "express";
import { PORT } from "./config.js";
import usersRoutes from "./routes/users.routes.js";
const app = express();

app.get("/", (req, res) => {
  res.send("Hello World");
});
app.use( usersRoutes);

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});