import { Router } from 'express';
import pool from '../db.js';
const router = Router();

// GET /api/pengukuran — all measurements with child name
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT p.*, b.nama AS nama_balita, k.tanggal_kunjungan
      FROM pengukuran p
      JOIN kunjungan k ON k.id_kunjungan = p.id_kunjungan
      JOIN balita b ON b.id_balita = k.id_balita
      ORDER BY p.tanggal_ukur DESC
    `);
    res.json({ success: true, count: result.rows.length, data: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/pengukuran/balita/:id_balita — growth history for one child (time-series)
router.get('/balita/:id_balita', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT p.*, k.tanggal_kunjungan
      FROM pengukuran p
      JOIN kunjungan k ON k.id_kunjungan = p.id_kunjungan
      WHERE k.id_balita = $1
      ORDER BY k.tanggal_kunjungan ASC
    `, [req.params.id_balita]);
    res.json({ success: true, count: result.rows.length, data: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/pengukuran — z-scores calculated automatically by DB trigger
// Body: { id_kunjungan, berat_badan, tinggi_badan, lingkar_kepala, tanggal_ukur?, catatan? }
router.post('/', async (req, res) => {
  try {
    const { id_kunjungan, berat_badan, tinggi_badan, lingkar_kepala, tanggal_ukur, catatan } = req.body;
    const result = await pool.query(
      `INSERT INTO pengukuran (id_kunjungan, berat_badan, tinggi_badan, lingkar_kepala, usia_bulan, tanggal_ukur, catatan)
       VALUES ($1, $2, $3, $4, 0, COALESCE($5, CURRENT_DATE), $6)
       RETURNING *`,
      [id_kunjungan, berat_badan, tinggi_badan, lingkar_kepala, tanggal_ukur ?? null, catatan ?? null]
    );
    res.status(201).json({ success: true, data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/pengukuran/:id
router.put('/:id', async (req, res) => {
  try {
    const { berat_badan, tinggi_badan, lingkar_kepala, catatan } = req.body;
    const result = await pool.query(
      `UPDATE pengukuran SET
         berat_badan   = COALESCE($1, berat_badan),
         tinggi_badan  = COALESCE($2, tinggi_badan),
         lingkar_kepala= COALESCE($3, lingkar_kepala),
         catatan       = COALESCE($4, catatan)
       WHERE id_pengukuran = $5 RETURNING *`,
      [berat_badan ?? null, tinggi_badan ?? null, lingkar_kepala ?? null, catatan ?? null, req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Pengukuran tidak ditemukan' });
    res.json({ success: true, data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/pengukuran/:id
router.delete('/:id', async (req, res) => {
  try {
    const result = await pool.query(
      `DELETE FROM pengukuran WHERE id_pengukuran = $1 RETURNING id_pengukuran`,
      [req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Pengukuran tidak ditemukan' });
    res.json({ success: true, message: `Pengukuran ${result.rows[0].id_pengukuran} dihapus` });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

export default router;