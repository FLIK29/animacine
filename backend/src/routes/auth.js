// src/routes/auth.js
const express = require('express');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const { getPool, sql } = require('../db');

const router = express.Router();

// ── POST /api/auth/registro ──────────────────────────────────
router.post('/registro', async (req, res) => {
  const { nombre, email, password } = req.body;

  if (!nombre || !email || !password)
    return res.status(400).json({ error: 'Nombre, email y password son requeridos' });

  if (password.length < 6)
    return res.status(400).json({ error: 'El password debe tener al menos 6 caracteres' });

  try {
    const pool = await getPool();

    // Verificar si el email ya existe
    const existe = await pool.request()
      .input('email', sql.NVarChar, email)
      .query('SELECT UsuarioID FROM Usuarios WHERE Email = @email');

    if (existe.recordset.length > 0)
      return res.status(409).json({ error: 'El email ya está registrado' });

    const hash = await bcrypt.hash(password, 12);

    const result = await pool.request()
      .input('nombre',       sql.NVarChar, nombre)
      .input('email',        sql.NVarChar, email)
      .input('passwordHash', sql.NVarChar, hash)
      .query(`
        INSERT INTO Usuarios (Nombre, Email, PasswordHash)
        OUTPUT INSERTED.UsuarioID, INSERTED.Nombre, INSERTED.Email
        VALUES (@nombre, @email, @passwordHash)
      `);

    const usuario = result.recordset[0];
    const token   = generarToken(usuario.UsuarioID, usuario.Email, 'Usuario');

    res.status(201).json({ token, usuario: { id: usuario.UsuarioID, nombre: usuario.Nombre, email: usuario.Email, rol: 'Usuario' } });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

// ── POST /api/auth/login ─────────────────────────────────────
router.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password)
    return res.status(400).json({ error: 'Email y password son requeridos' });

  try {
    const pool = await getPool();

    const result = await pool.request()
      .input('email', sql.NVarChar, email)
      .query(`
        SELECT u.UsuarioID, u.Nombre, u.Email, u.PasswordHash, u.Activo, r.Nombre AS Rol
        FROM Usuarios u
        JOIN Roles r ON u.RolID = r.RolID
        WHERE u.Email = @email
      `);

    const usuario = result.recordset[0];

    if (!usuario)
      return res.status(401).json({ error: 'Credenciales incorrectas' });

    if (!usuario.Activo)
      return res.status(403).json({ error: 'Cuenta desactivada' });

    const valido = await bcrypt.compare(password, usuario.PasswordHash);
    if (!valido)
      return res.status(401).json({ error: 'Credenciales incorrectas' });

    const token = generarToken(usuario.UsuarioID, usuario.Email, usuario.Rol);

    res.json({
      token,
      usuario: { id: usuario.UsuarioID, nombre: usuario.Nombre, email: usuario.Email, rol: usuario.Rol }
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error interno del servidor' });
  }
});

function generarToken(id, email, rol) {
  return jwt.sign({ id, email, rol }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN });
}

module.exports = router;
