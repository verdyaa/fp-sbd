import { Router } from 'express';
import pool from '../db.js';
const router = Router();

// GET /api/kunjungan — all visits
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT k.*, b.nama AS nama_balita, kd.nama AS nama_kader, p.nama_posyandu
      FROM kunjungan k
      JOIN balita b ON b.id_balita = k.id_balita
      JOIN kader kd ON kd.id_kader = k.id_kader
      JOIN posyandu p ON p.id_posyandu = k.id_posyandu
      ORDER BY k.tanggal_kunjungan DESC
    `);
    res.json({ success: true, count: result.rows.length, data: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/kunjungan/:id
router.get('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT k.*, b.nama AS nama_balita, kd.nama AS nama_kader, p.nama_posyandu
       FROM kunjungan k
       JOIN balita b ON b.id_balita = k.id_balita
       JOIN kader kd ON kd.id_kader = k.id_kader
       JOIN posyandu p ON p.id_posyandu = k.id_posyandu
       WHERE k.id_kunjungan = $1`,
      [req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Kunjungan tidak ditemukan' });
    res.json({ success: true, data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/kunjungan
// Body: { id_balita, id_kader, id_posyandu, tanggal_kunjungan, jenis_kunjungan, waktu_mulai?, waktu_selesai?, status_kesehatan? }
router.post('/', async (req, res) => {
  try {
    const { id_balita, id_kader, id_posyandu, tanggal_kunjungan, jenis_kunjungan, waktu_mulai, waktu_selesai, status_kesehatan } = req.body;
    const result = await pool.query(
      `INSERT INTO kunjungan (id_balita, id_kader, id_posyandu, tanggal_kunjungan, jenis_kunjungan, waktu_mulai, waktu_selesai, status_kesehatan)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [id_balita, id_kader, id_posyandu, tanggal_kunjungan, jenis_kunjungan, waktu_mulai ?? null, waktu_selesai ?? null, status_kesehatan ?? null]
    );
    res.status(201).json({ success: true, data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/kunjungan/:id
router.put('/:id', async (req, res) => {
  try {
    const { jenis_kunjungan, waktu_mulai, waktu_selesai, status_kesehatan } = req.body;
    const result = await pool.query(
      `UPDATE kunjungan SET
         jenis_kunjungan = COALESCE($1, jenis_kunjungan),
         waktu_mulai     = COALESCE($2, waktu_mulai),
         waktu_selesai   = COALESCE($3, waktu_selesai),
         status_kesehatan= COALESCE($4, status_kesehatan)
       WHERE id_kunjungan = $5 RETURNING *`,
      [jenis_kunjungan ?? null, waktu_mulai ?? null, waktu_selesai ?? null, status_kesehatan ?? null, req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Kunjungan tidak ditemukan' });
    res.json({ success: true, data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/kunjungan/:id
router.delete('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      `DELETE FROM kunjungan WHERE id_kunjungan = $1 RETURNING id_kunjungan`,
      [req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Kunjungan tidak ditemukan' });
    res.json({ success: true, message: `Kunjungan ${result.rows[0].id_kunjungan} dihapus` });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

export default router;