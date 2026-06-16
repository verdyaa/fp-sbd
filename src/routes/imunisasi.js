import { Router } from 'express';
import pool from '../db.js';
const router = Router();

// GET /api/imunisasi — all vaccine types
router.get('/', async (req, res) => {
  try {
    const result = await pool.query(`SELECT * FROM imunisasi ORDER BY id_imunisasi`);
    res.json({ success: true, data: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// GET /api/imunisasi/balita/:id_balita — immunization records for one child
router.get('/balita/:id_balita', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT i.nama_imunisasi, i.jumlah_dosis_total,
             bi.dosis_ke, bi.tanggal_pemberian, bi.status_pemberian,
             bi.lokasi_pemberian, bi.petugas_pemberian
      FROM imunisasi i
      LEFT JOIN balita_imunisasi bi
             ON bi.id_imunisasi = i.id_imunisasi AND bi.id_balita = $1
      ORDER BY i.id_imunisasi, bi.dosis_ke
    `, [req.params.id_balita]);
    res.json({ success: true, data: result.rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// POST /api/imunisasi/balita — record a vaccine given to a child
// Body: { id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian?, petugas_pemberian? }
router.post('/balita', async (req, res) => {
  try {
    const { id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian, petugas_pemberian } = req.body;
    const result = await pool.query(
      `INSERT INTO balita_imunisasi (id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian, petugas_pemberian)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian ?? null, petugas_pemberian ?? null]
    );
    res.status(201).json({ success: true, data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// PUT /api/imunisasi/balita/:id_balita/:id_imunisasi/:dosis_ke
router.put('/balita/:id_balita/:id_imunisasi/:dosis_ke', async (req, res) => {
  try {
    const { status_pemberian, lokasi_pemberian, petugas_pemberian } = req.body;
    const { id_balita, id_imunisasi, dosis_ke } = req.params;
    const result = await pool.query(
      `UPDATE balita_imunisasi SET
         status_pemberian  = COALESCE($1, status_pemberian),
         lokasi_pemberian  = COALESCE($2, lokasi_pemberian),
         petugas_pemberian = COALESCE($3, petugas_pemberian)
       WHERE id_balita=$4 AND id_imunisasi=$5 AND dosis_ke=$6 RETURNING *`,
      [status_pemberian ?? null, lokasi_pemberian ?? null, petugas_pemberian ?? null, id_balita, id_imunisasi, dosis_ke]
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Record tidak ditemukan' });
    res.json({ success: true, data: result.rows[0] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// DELETE /api/imunisasi/balita/:id_balita/:id_imunisasi/:dosis_ke
router.delete('/balita/:id_balita/:id_imunisasi/:dosis_ke', async (req, res) => {
  try {
    const { id_balita, id_imunisasi, dosis_ke } = req.params;
    const result = await pool.query(
      `DELETE FROM balita_imunisasi WHERE id_balita=$1 AND id_imunisasi=$2 AND dosis_ke=$3 RETURNING *`,
      [id_balita, id_imunisasi, dosis_ke]
    );
    if (result.rows.length === 0) return res.status(404).json({ success: false, message: 'Record tidak ditemukan' });
    res.json({ success: true, message: 'Record imunisasi dihapus' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

export default router;