const express = require("express");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

// Servir el index.html que está en la carpeta /app
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "index.html"));
});

// Backend API
app.get("/api/hello", (req, res) => {
  res.json({
    message: "Hola desde el backend ✅ (Terraform + AWS + ALB + ASG) - Andy Alarcón"
  });
});

// Health check (para AWS ALB)
app.get("/health", (req, res) => res.status(200).send("OK"));

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Servidor escuchando en puerto ${PORT}`);
});


