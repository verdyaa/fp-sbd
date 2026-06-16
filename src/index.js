import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

import balitaRoutes from './routes/balita.js';
import kunjunganRoutes from './routes/kunjungan.js';
import pengukuranRoutes from './routes/pengukuran.js';
import imunisasiRoutes from './routes/imunisasi.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware — runs on every request before your route handlers
app.use(cors());
app.use(express.json()); // lets Express read JSON request bodies

// Routes
app.use('/api/balita',     balitaRoutes);
app.use('/api/kunjungan',  kunjunganRoutes);
app.use('/api/pengukuran', pengukuranRoutes);
app.use('/api/imunisasi',  imunisasiRoutes);

// Health check — hit this first to confirm server is alive
app.get('/', (req, res) => {
  res.json({ message: 'Posyandu API is running' });
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});