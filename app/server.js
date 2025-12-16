const express = require("express");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

// ✅ Health check (AWS ALB Target Group -> /health)
app.get("/health", (req, res) => {
  res.status(200).send("OK");
});

// ✅ API
app.get("/api/hello", (req, res) => {
  res.json({
    message: "Hola desde el backend ✅ (Terraform + AWS + ALB + ASG) - Andy Alarcón"
  });
});

// ✅ Servir estático si luego tienes archivos (opcional pero recomendado)
app.use(express.static(__dirname));

// ✅ Ruta principal: sirve index.html
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "index.html"));
});

// ✅ Cualquier otra ruta devuelve index.html (evita 404)
app.get("*", (req, res) => {
  res.sendFile(path.join(__dirname, "index.html"));
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Servidor escuchando en puerto ${PORT}`);
});

