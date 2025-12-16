const express = require("express");
const path = require("path");
const app = express();
const PORT = process.env.PORT || 3000;

// Servir el frontend estático
app.use(express.static(path.join(__dirname, "public")));

// Endpoint backend
app.get("/api/hello", (req, res) => {
  res.json({
    message: "Hola desde el backend en AWS con Auto Scaling - Andy Alarcón"
  });
});

// Cualquier otra ruta => index.html
app.get("*", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Servidor escuchando en puerto ${PORT}`);
});

