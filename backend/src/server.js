// src/server.js — Entrada principal
require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const { getPool } = require('./db');

const authRouter      = require('./routes/auth');
const peliculasRouter = require('./routes/peliculas');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Middlewares globales ──────────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Rutas ────────────────────────────────────────────────────
app.use('/api/auth',      authRouter);
app.use('/api/peliculas', peliculasRouter);

// ── Health check ─────────────────────────────────────────────
app.get('/api/health', (req, res) => res.json({ status: 'ok', timestamp: new Date() }));

// ── 404 ──────────────────────────────────────────────────────
app.use((req, res) => res.status(404).json({ error: 'Ruta no encontrada' }));

// ── Arrancar servidor ─────────────────────────────────────────
async function start() {
  await getPool();           // conectar a DB al arrancar
  app.listen(PORT, () => {
    console.log(`🎬 AnimaCine API corriendo en http://localhost:${PORT}`);
    console.log(`   Health: http://localhost:${PORT}/api/health`);
  });
}

start().catch(console.error);
