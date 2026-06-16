import { Router } from 'express';
import pool from '../db.js';

const router = Router();

// ── READ ALL ──────────────────────────────────────────────
// GET /api/balita
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        b.id_balita, b.nama, b.tanggal_lahir, b.jenis_kelamin,
        b.alamat, b.nik, b.golongan_darah, b.status_aktif,
        o.nama    AS nama_ortu,
        o.no_hp   AS no_hp_ortu
      FROM balita b
      JOIN orangtua o ON o.id_ortu = b.id_ortu
      WHERE b.status_aktif = TRUE
      ORDER BY b.nama ASC
    `);
    res.json({ success: true, count: result.rows.length, data: result.rows });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── READ ONE ──────────────────────────────────────────────
// GET /api/balita/:id
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `SELECT b.*, o.nama AS nama_ortu, o.no_hp AS no_hp_ortu
       FROM balita b
       JOIN orangtua o ON o.id_ortu = b.id_ortu
       WHERE b.id_balita = $1`,
      [id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Balita tidak ditemukan' });
    }
    res.json({ success: true, data: result.rows[0] });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── CREATE ────────────────────────────────────────────────
// POST /api/balita
// Body: { id_ortu, nama, tanggal_lahir, jenis_kelamin, alamat, nik?, berat_lahir?, panjang_lahir?, golongan_darah? }
router.post('/', async (req, res) => {
  try {
    const { id_ortu, nama, tanggal_lahir, jenis_kelamin, alamat, nik, berat_lahir, panjang_lahir, golongan_darah } = req.body;

    const result = await pool.query(
      `INSERT INTO balita (id_ortu, nama, tanggal_lahir, jenis_kelamin, alamat, nik, berat_lahir, panjang_lahir, golongan_darah)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [id_ortu, nama, tanggal_lahir, jenis_kelamin, alamat, nik ?? null, berat_lahir ?? null, panjang_lahir ?? null, golongan_darah ?? null]
    );
    res.status(201).json({ success: true, data: result.rows[0] });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── UPDATE ────────────────────────────────────────────────
// PUT /api/balita/:id
// Body: any fields you want to update
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { nama, alamat, golongan_darah, status_aktif, tanggal_keluar, alasan_keluar } = req.body;

    const result = await pool.query(
      `UPDATE balita
       SET nama = COALESCE($1, nama),
           alamat = COALESCE($2, alamat),
           golongan_darah = COALESCE($3, golongan_darah),
           status_aktif = COALESCE($4, status_aktif),
           tanggal_keluar = COALESCE($5, tanggal_keluar),
           alasan_keluar = COALESCE($6, alasan_keluar)
       WHERE id_balita = $7
       RETURNING *`,
      [nama ?? null, alamat ?? null, golongan_darah ?? null, status_aktif ?? null, tanggal_keluar ?? null, alasan_keluar ?? null, id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Balita tidak ditemukan' });
    }
    res.json({ success: true, data: result.rows[0] });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── DELETE ────────────────────────────────────────────────
// DELETE /api/balita/:id
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      `DELETE FROM balita WHERE id_balita = $1 RETURNING id_balita, nama`,
      [id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, message: 'Balita tidak ditemukan' });
    }
    res.json({ success: true, message: `Balita ${result.rows[0].nama} dihapus` });
  } catch (err) {
    console.error(err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

export default router;