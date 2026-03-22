// src/routes/peliculas.js
const express = require('express');
const { getPool, sql } = require('../db');
const { authMiddleware, adminMiddleware } = require('../middleware/auth');

const router = express.Router();

// ── GET /api/peliculas ── Catálogo público (con filtros) ─────
router.get('/', async (req, res) => {
  const { genero, busqueda } = req.query;
  try {
    const pool    = await getPool();
    const request = pool.request();

    if (genero)   request.input('Genero',   sql.NVarChar, genero);
    if (busqueda) request.input('Busqueda', sql.NVarChar, busqueda);

    const result = await request.execute('sp_ObtenerCatalogo');
    res.json(result.recordset);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener catálogo' });
  }
});

// ── GET /api/peliculas/:id ── Detalle de una película ────────
router.get('/:id', async (req, res) => {
  try {
    const pool   = await getPool();
    const result = await pool.request()
      .input('id', sql.Int, req.params.id)
      .query('SELECT * FROM vw_Catalogo WHERE PeliculaID = @id');

    if (!result.recordset.length)
      return res.status(404).json({ error: 'Película no encontrada' });

    res.json(result.recordset[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener película' });
  }
});

// ── GET /api/peliculas/generos/lista ── Lista de géneros ─────
router.get('/generos/lista', async (req, res) => {
  try {
    const pool   = await getPool();
    const result = await pool.request().query('SELECT * FROM Generos ORDER BY Nombre');
    res.json(result.recordset);
  } catch (err) {
    res.status(500).json({ error: 'Error al obtener géneros' });
  }
});

// ── POST /api/peliculas/:id/calificar ── (requiere login) ────
router.post('/:id/calificar', authMiddleware, async (req, res) => {
  const { puntaje } = req.body;

  if (!puntaje || puntaje < 1 || puntaje > 5)
    return res.status(400).json({ error: 'El puntaje debe ser entre 1 y 5' });

  try {
    const pool = await getPool();
    await pool.request()
      .input('UsuarioID',  sql.Int,    req.user.id)
      .input('PeliculaID', sql.Int,    req.params.id)
      .input('Puntaje',    sql.TinyInt, puntaje)
      .execute('sp_CalificarPelicula');

    res.json({ mensaje: 'Calificación guardada', puntaje });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al guardar calificación' });
  }
});

// ── POST /api/peliculas/:id/favorito ── Toggle (requiere login)
router.post('/:id/favorito', authMiddleware, async (req, res) => {
  try {
    const pool   = await getPool();
    const result = await pool.request()
      .input('UsuarioID',  sql.Int, req.user.id)
      .input('PeliculaID', sql.Int, req.params.id)
      .execute('sp_ToggleFavorito');

    res.json({ estado: result.recordset[0].Estado });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al gestionar favorito' });
  }
});

// ── GET /api/peliculas/usuario/favoritos ── (requiere login) ─
router.get('/usuario/favoritos', authMiddleware, async (req, res) => {
  try {
    const pool   = await getPool();
    const result = await pool.request()
      .input('UsuarioID', sql.Int, req.user.id)
      .execute('sp_ObtenerFavoritos');

    res.json(result.recordset);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al obtener favoritos' });
  }
});

// ════════════════════════════════════════════════════════════
//  RUTAS DE ADMINISTRADOR
// ════════════════════════════════════════════════════════════

// ── POST /api/peliculas ── Agregar película (solo admin) ─────
router.post('/', authMiddleware, adminMiddleware, async (req, res) => {
  const { titulo, sinopsis, anio, duracion, posterURL, generoID, estudioID } = req.body;

  if (!titulo || !anio || !generoID || !estudioID)
    return res.status(400).json({ error: 'Título, año, género y estudio son requeridos' });

  try {
    const pool   = await getPool();
    const result = await pool.request()
      .input('titulo',    sql.NVarChar, titulo)
      .input('sinopsis',  sql.NVarChar, sinopsis || null)
      .input('anio',      sql.SmallInt, anio)
      .input('duracion',  sql.SmallInt, duracion || null)
      .input('posterURL', sql.NVarChar, posterURL || null)
      .input('generoID',  sql.Int,      generoID)
      .input('estudioID', sql.Int,      estudioID)
      .query(`
        INSERT INTO Peliculas (Titulo, Sinopsis, Anio, Duracion, PosterURL, GeneroID, EstudioID)
        OUTPUT INSERTED.PeliculaID
        VALUES (@titulo, @sinopsis, @anio, @duracion, @posterURL, @generoID, @estudioID)
      `);

    res.status(201).json({ id: result.recordset[0].PeliculaID, mensaje: 'Película agregada' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al agregar película' });
  }
});

// ── PUT /api/peliculas/:id ── Editar película (solo admin) ───
router.put('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  const { titulo, sinopsis, anio, duracion, posterURL, generoID, estudioID } = req.body;

  try {
    const pool = await getPool();
    await pool.request()
      .input('id',        sql.Int,      req.params.id)
      .input('titulo',    sql.NVarChar, titulo)
      .input('sinopsis',  sql.NVarChar, sinopsis || null)
      .input('anio',      sql.SmallInt, anio)
      .input('duracion',  sql.SmallInt, duracion || null)
      .input('posterURL', sql.NVarChar, posterURL || null)
      .input('generoID',  sql.Int,      generoID)
      .input('estudioID', sql.Int,      estudioID)
      .query(`
        UPDATE Peliculas SET
          Titulo    = @titulo,
          Sinopsis  = @sinopsis,
          Anio      = @anio,
          Duracion  = @duracion,
          PosterURL = @posterURL,
          GeneroID  = @generoID,
          EstudioID = @estudioID
        WHERE PeliculaID = @id
      `);

    res.json({ mensaje: 'Película actualizada' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al actualizar película' });
  }
});

// ── DELETE /api/peliculas/:id ── Desactivar (solo admin) ─────
router.delete('/:id', authMiddleware, adminMiddleware, async (req, res) => {
  try {
    const pool = await getPool();
    await pool.request()
      .input('id', sql.Int, req.params.id)
      .query('UPDATE Peliculas SET Activa = 0 WHERE PeliculaID = @id');

    res.json({ mensaje: 'Película eliminada del catálogo' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Error al eliminar película' });
  }
});

module.exports = router;
