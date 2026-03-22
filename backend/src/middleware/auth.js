// src/middleware/auth.js
const jwt = require('jsonwebtoken');

function authMiddleware(req, res, next) {
  const header = req.headers['authorization'];
  const token  = header && header.split(' ')[1]; // Bearer <token>

  if (!token)
    return res.status(401).json({ error: 'Token requerido' });

  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(403).json({ error: 'Token inválido o expirado' });
  }
}

function adminMiddleware(req, res, next) {
  if (req.user?.rol !== 'Administrador')
    return res.status(403).json({ error: 'Acceso solo para administradores' });
  next();
}

module.exports = { authMiddleware, adminMiddleware };
