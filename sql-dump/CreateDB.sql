-- ============================================================
-- SISTEM INFORMASI POSYANDU
-- Complete Database Setup — Single File
-- PostgreSQL / Supabase
--
-- Execution order (all handled automatically in this file):
--   1. Clean slate (drop everything if exists)
--   2. Tables
--   3. Indexes
--   4. Functions & Triggers (updated_at + z-score)
--   5. Views
--   6. WHO Standard Reference Data (488 rows)
--   7. Seed Data (kader, posyandu, imunisasi, orangtua,
--                 balita, kunjungan, pengukuran,
--                 catatan_kader, balita_imunisasi)
-- ============================================================


-- ============================================================
-- SECTION 1: CLEAN SLATE
-- Drop in reverse FK dependency order so nothing blocks drops
-- ============================================================

DROP VIEW  IF EXISTS v_stunting_risk       CASCADE;
DROP VIEW  IF EXISTS v_immunization_status CASCADE;
DROP VIEW  IF EXISTS v_growth_tracking     CASCADE;

DROP TABLE IF EXISTS balita_imunisasi   CASCADE;
DROP TABLE IF EXISTS catatan_kader      CASCADE;
DROP TABLE IF EXISTS pengukuran         CASCADE;
DROP TABLE IF EXISTS kunjungan          CASCADE;
DROP TABLE IF EXISTS balita             CASCADE;
DROP TABLE IF EXISTS orangtua           CASCADE;
DROP TABLE IF EXISTS imunisasi          CASCADE;
DROP TABLE IF EXISTS kader              CASCADE;
DROP TABLE IF EXISTS posyandu           CASCADE;
DROP TABLE IF EXISTS standar_pertumbuhan CASCADE;

DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS calculate_z_scores()       CASCADE;


-- ============================================================
-- SECTION 2: TABLES
-- ============================================================

-- 1. ORANGTUA
CREATE TABLE orangtua (
  id_ortu    SERIAL PRIMARY KEY,
  nama       VARCHAR(100) NOT NULL,
  no_hp      VARCHAR(20)  NOT NULL,
  alamat     TEXT         NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 2. BALITA
CREATE TABLE balita (
  id_balita          SERIAL PRIMARY KEY,
  id_ortu            INTEGER      NOT NULL REFERENCES orangtua(id_ortu) ON DELETE RESTRICT,
  nama               VARCHAR(100) NOT NULL,
  tanggal_lahir      DATE         NOT NULL,
  jenis_kelamin      VARCHAR(10)  NOT NULL CHECK (jenis_kelamin IN ('Laki-laki', 'Perempuan')),
  alamat             TEXT         NOT NULL,
  nik                VARCHAR(20)  UNIQUE,
  berat_lahir        DECIMAL(5,2),
  panjang_lahir      DECIMAL(5,2),
  status_aktif       BOOLEAN      NOT NULL DEFAULT TRUE,
  tanggal_registrasi DATE         NOT NULL DEFAULT CURRENT_DATE,
  tanggal_keluar     DATE,
  alasan_keluar      TEXT,
  golongan_darah     VARCHAR(5),
  created_at         TIMESTAMP DEFAULT NOW(),
  updated_at         TIMESTAMP DEFAULT NOW(),
  CONSTRAINT chk_tanggal_keluar CHECK (tanggal_keluar IS NULL OR tanggal_keluar >= tanggal_registrasi)
);

-- 3. KADER
CREATE TABLE kader (
  id_kader   SERIAL PRIMARY KEY,
  nama       VARCHAR(100) NOT NULL,
  no_hp      VARCHAR(20)  NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 4. POSYANDU
CREATE TABLE posyandu (
  id_posyandu   SERIAL PRIMARY KEY,
  nama_posyandu VARCHAR(150) NOT NULL,
  lokasi        TEXT         NOT NULL,
  created_at    TIMESTAMP DEFAULT NOW(),
  updated_at    TIMESTAMP DEFAULT NOW()
);

-- 5. IMUNISASI
CREATE TABLE imunisasi (
  id_imunisasi         SERIAL PRIMARY KEY,
  nama_imunisasi       VARCHAR(100) NOT NULL,
  usia_target          VARCHAR(50)  NOT NULL,
  jumlah_dosis_total   INTEGER      NOT NULL DEFAULT 1,
  interval_minimum_hari INTEGER,
  is_mandatory         BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at           TIMESTAMP DEFAULT NOW(),
  updated_at           TIMESTAMP DEFAULT NOW()
);

-- 6. STANDAR_PERTUMBUHAN (WHO reference — uses 'indeks' not 'usia_bulan')
--    indeks = age in months for BB/U, TB/U, LK/U
--    indeks = height in cm   for BB/TB
CREATE TABLE standar_pertumbuhan (
  id_standar    SERIAL PRIMARY KEY,
  jenis_kelamin VARCHAR(10)  NOT NULL CHECK (jenis_kelamin IN ('Laki-laki', 'Perempuan')),
  indeks        INTEGER      NOT NULL,
  tipe_metrik   VARCHAR(20)  NOT NULL CHECK (tipe_metrik IN ('BB/U', 'TB/U', 'BB/TB', 'LK/U')),
  nilai_l       DECIMAL(10,6) NOT NULL,
  nilai_m       DECIMAL(10,6) NOT NULL,
  nilai_s       DECIMAL(10,6) NOT NULL,
  created_at    TIMESTAMP DEFAULT NOW(),
  UNIQUE (jenis_kelamin, indeks, tipe_metrik)
);

-- 7. KUNJUNGAN
CREATE TABLE kunjungan (
  id_kunjungan     SERIAL PRIMARY KEY,
  id_balita        INTEGER     NOT NULL REFERENCES balita(id_balita)   ON DELETE CASCADE,
  id_kader         INTEGER     NOT NULL REFERENCES kader(id_kader)     ON DELETE RESTRICT,
  id_posyandu      INTEGER     NOT NULL REFERENCES posyandu(id_posyandu) ON DELETE RESTRICT,
  tanggal_kunjungan DATE       NOT NULL DEFAULT CURRENT_DATE,
  jenis_kunjungan  VARCHAR(50) NOT NULL,
  waktu_mulai      TIME,
  waktu_selesai    TIME,
  status_kesehatan VARCHAR(50),
  created_at       TIMESTAMP DEFAULT NOW(),
  updated_at       TIMESTAMP DEFAULT NOW(),
  CONSTRAINT chk_waktu CHECK (waktu_selesai IS NULL OR waktu_mulai IS NULL OR waktu_selesai >= waktu_mulai)
);

-- 8. PENGUKURAN
CREATE TABLE pengukuran (
  id_pengukuran      SERIAL PRIMARY KEY,
  id_kunjungan       INTEGER      NOT NULL REFERENCES kunjungan(id_kunjungan) ON DELETE CASCADE,
  berat_badan        DECIMAL(5,2) NOT NULL CHECK (berat_badan > 0),
  tinggi_badan       DECIMAL(5,2) NOT NULL CHECK (tinggi_badan > 0),
  lingkar_kepala     DECIMAL(5,2) NOT NULL CHECK (lingkar_kepala > 0),
  usia_bulan         INTEGER      NOT NULL CHECK (usia_bulan >= 0),
  z_score_tb_u       DECIMAL(5,2),
  z_score_bb_u       DECIMAL(5,2),
  z_score_bb_tb      DECIMAL(5,2),
  status_gizi        VARCHAR(50),
  flag_risiko_stunting BOOLEAN    DEFAULT FALSE,
  tingkat_risiko     VARCHAR(20),
  tanggal_ukur       DATE         NOT NULL DEFAULT CURRENT_DATE,
  catatan            TEXT,
  created_at         TIMESTAMP DEFAULT NOW(),
  updated_at         TIMESTAMP DEFAULT NOW(),
  UNIQUE (id_kunjungan)
);

-- 9. CATATAN_KADER
CREATE TABLE catatan_kader (
  id_catatan       SERIAL PRIMARY KEY,
  id_kunjungan     INTEGER NOT NULL REFERENCES kunjungan(id_kunjungan) ON DELETE CASCADE,
  observasi_kader  TEXT,
  keluhan_ortu     TEXT,
  tindakan         TEXT,
  rekomendasi      TEXT,
  tanggal_followup DATE,
  created_at       TIMESTAMP DEFAULT NOW(),
  updated_at       TIMESTAMP DEFAULT NOW()
);

-- 10. BALITA_IMUNISASI
CREATE TABLE balita_imunisasi (
  id_balita         INTEGER     NOT NULL REFERENCES balita(id_balita)     ON DELETE CASCADE,
  id_imunisasi      INTEGER     NOT NULL REFERENCES imunisasi(id_imunisasi) ON DELETE RESTRICT,
  dosis_ke          INTEGER     NOT NULL DEFAULT 1 CHECK (dosis_ke > 0),
  tanggal_pemberian DATE        NOT NULL,
  status_pemberian  VARCHAR(20) NOT NULL CHECK (status_pemberian IN ('Diberikan', 'Tertunda', 'Batal')),
  lokasi_pemberian  VARCHAR(100),
  petugas_pemberian VARCHAR(100),
  batch_number      VARCHAR(50),
  keterangan        TEXT,
  created_at        TIMESTAMP DEFAULT NOW(),
  updated_at        TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (id_balita, id_imunisasi, dosis_ke)
);


-- ============================================================
-- SECTION 3: INDEXES
-- ============================================================

CREATE INDEX idx_balita_ortu          ON balita(id_ortu);
CREATE INDEX idx_balita_tanggal_lahir ON balita(tanggal_lahir);
CREATE INDEX idx_balita_status_aktif  ON balita(status_aktif) WHERE status_aktif = TRUE;
CREATE INDEX idx_balita_nik           ON balita(nik)          WHERE nik IS NOT NULL;

CREATE INDEX idx_kunjungan_balita     ON kunjungan(id_balita);
CREATE INDEX idx_kunjungan_kader      ON kunjungan(id_kader);
CREATE INDEX idx_kunjungan_posyandu   ON kunjungan(id_posyandu);
CREATE INDEX idx_kunjungan_tanggal    ON kunjungan(tanggal_kunjungan);

CREATE INDEX idx_pengukuran_kunjungan ON pengukuran(id_kunjungan);
CREATE INDEX idx_pengukuran_stunting  ON pengukuran(flag_risiko_stunting) WHERE flag_risiko_stunting = TRUE;
CREATE INDEX idx_pengukuran_tanggal   ON pengukuran(tanggal_ukur);

CREATE INDEX idx_catatan_kunjungan    ON catatan_kader(id_kunjungan);
CREATE INDEX idx_catatan_followup     ON catatan_kader(tanggal_followup) WHERE tanggal_followup IS NOT NULL;

CREATE INDEX idx_balita_imunisasi_balita  ON balita_imunisasi(id_balita);
CREATE INDEX idx_balita_imunisasi_tanggal ON balita_imunisasi(tanggal_pemberian);

CREATE INDEX idx_standar_lookup ON standar_pertumbuhan(jenis_kelamin, indeks, tipe_metrik);


-- ============================================================
-- SECTION 4: FUNCTIONS & TRIGGERS
-- ============================================================

-- ── 4a. Auto-update updated_at ───────────────────────────────

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_orangtua_updated_at
  BEFORE UPDATE ON orangtua
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_balita_updated_at
  BEFORE UPDATE ON balita
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_kader_updated_at
  BEFORE UPDATE ON kader
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posyandu_updated_at
  BEFORE UPDATE ON posyandu
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_imunisasi_updated_at
  BEFORE UPDATE ON imunisasi
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_kunjungan_updated_at
  BEFORE UPDATE ON kunjungan
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pengukuran_updated_at
  BEFORE UPDATE ON pengukuran
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_catatan_kader_updated_at
  BEFORE UPDATE ON catatan_kader
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_balita_imunisasi_updated_at
  BEFORE UPDATE ON balita_imunisasi
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();


-- ── 4b. Z-Score Calculation Trigger ─────────────────────────
--
-- Fires BEFORE INSERT OR UPDATE on pengukuran.
-- Automatically calculates:
--   z_score_bb_u   → BB/U  → sets status_gizi
--   z_score_tb_u   → TB/U  → sets flag_risiko_stunting & tingkat_risiko
--   z_score_bb_tb  → BB/TB
--   usia_bulan     → derived from tanggal_lahir & tanggal_kunjungan
--
-- Formula (Box-Cox WHO):
--   if L = 1 : Z = (X - M) / (M * S)
--   if L ≠ 1 : Z = ((X/M)^L - 1) / (L * S)

CREATE OR REPLACE FUNCTION calculate_z_scores()
RETURNS TRIGGER AS $$
DECLARE
  v_jenis_kelamin   VARCHAR;
  v_tanggal_lahir   DATE;
  v_tanggal_kunjungan DATE;
  v_umur_bulan      INTEGER;
  v_l NUMERIC; v_m NUMERIC; v_s NUMERIC;
  v_z NUMERIC;
BEGIN
  -- Fetch gender, birth date, and visit date via the kunjungan → balita chain
  SELECT b.jenis_kelamin, b.tanggal_lahir, k.tanggal_kunjungan
  INTO   v_jenis_kelamin, v_tanggal_lahir, v_tanggal_kunjungan
  FROM   kunjungan k
  JOIN   balita    b ON b.id_balita = k.id_balita
  WHERE  k.id_kunjungan = NEW.id_kunjungan;

  -- Derive age in whole months at the time of the visit
  v_umur_bulan := (EXTRACT(YEAR  FROM age(v_tanggal_kunjungan, v_tanggal_lahir)) * 12)
                + (EXTRACT(MONTH FROM age(v_tanggal_kunjungan, v_tanggal_lahir)));

  NEW.usia_bulan := v_umur_bulan;

  -- ── BB/U (Weight-for-Age) ──────────────────────────────────
  SELECT nilai_l, nilai_m, nilai_s
  INTO   v_l, v_m, v_s
  FROM   standar_pertumbuhan
  WHERE  jenis_kelamin = v_jenis_kelamin
    AND  indeks        = v_umur_bulan
    AND  tipe_metrik   = 'BB/U';

  IF FOUND AND NEW.berat_badan IS NOT NULL THEN
    IF v_l = 1 THEN
      v_z := (NEW.berat_badan - v_m) / (v_m * v_s);
    ELSE
      v_z := (POWER(NEW.berat_badan / v_m, v_l) - 1) / (v_l * v_s);
    END IF;
    NEW.z_score_bb_u := ROUND(v_z, 2);
    NEW.status_gizi  := CASE
      WHEN v_z < -3 THEN 'Gizi Buruk'
      WHEN v_z < -2 THEN 'Gizi Kurang'
      WHEN v_z <= 1 THEN 'Gizi Baik'
      ELSE               'Risiko Lebih'
    END;
  END IF;

  -- ── TB/U (Height-for-Age) ──────────────────────────────────
  SELECT nilai_l, nilai_m, nilai_s
  INTO   v_l, v_m, v_s
  FROM   standar_pertumbuhan
  WHERE  jenis_kelamin = v_jenis_kelamin
    AND  indeks        = v_umur_bulan
    AND  tipe_metrik   = 'TB/U';

  IF FOUND AND NEW.tinggi_badan IS NOT NULL THEN
    -- TB/U always has L = 1
    v_z := (NEW.tinggi_badan - v_m) / (v_m * v_s);
    NEW.z_score_tb_u        := ROUND(v_z, 2);
    NEW.flag_risiko_stunting := v_z < -2;
    NEW.tingkat_risiko       := CASE
      WHEN v_z < -3 THEN 'Tinggi'
      WHEN v_z < -2 THEN 'Sedang'
      ELSE               'Normal'
    END;
  END IF;

  -- ── BB/TB (Weight-for-Height) ──────────────────────────────
  -- indeks for BB/TB is height in cm rounded to nearest integer
  SELECT nilai_l, nilai_m, nilai_s
  INTO   v_l, v_m, v_s
  FROM   standar_pertumbuhan
  WHERE  jenis_kelamin = v_jenis_kelamin
    AND  indeks        = ROUND(NEW.tinggi_badan)::INTEGER
    AND  tipe_metrik   = 'BB/TB';

  IF FOUND AND NEW.berat_badan IS NOT NULL THEN
    IF v_l = 1 THEN
      v_z := (NEW.berat_badan - v_m) / (v_m * v_s);
    ELSE
      v_z := (POWER(NEW.berat_badan / v_m, v_l) - 1) / (v_l * v_s);
    END IF;
    NEW.z_score_bb_tb := ROUND(v_z, 2);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_z_scores
  BEFORE INSERT OR UPDATE OF berat_badan, tinggi_badan ON pengukuran
  FOR EACH ROW EXECUTE FUNCTION calculate_z_scores();


-- ============================================================
-- SECTION 5: VIEWS
-- ============================================================

-- Growth tracking time-series per balita
CREATE VIEW v_growth_tracking AS
SELECT
  b.id_balita,
  b.nama            AS nama_balita,
  b.jenis_kelamin,
  b.tanggal_lahir,
  k.tanggal_kunjungan,
  p.usia_bulan,
  p.berat_badan,
  p.tinggi_badan,
  p.lingkar_kepala,
  p.z_score_bb_u,
  p.z_score_tb_u,
  p.z_score_bb_tb,
  p.status_gizi,
  p.flag_risiko_stunting,
  pos.nama_posyandu
FROM balita b
JOIN kunjungan k  ON k.id_balita    = b.id_balita
JOIN pengukuran p ON p.id_kunjungan = k.id_kunjungan
JOIN posyandu pos ON pos.id_posyandu = k.id_posyandu
ORDER BY b.id_balita, k.tanggal_kunjungan;

-- Immunization status — shows NULL status_pemberian where vaccine not yet given
CREATE VIEW v_immunization_status AS
SELECT
  b.id_balita,
  b.nama            AS nama_balita,
  b.tanggal_lahir,
  (EXTRACT(YEAR  FROM AGE(CURRENT_DATE, b.tanggal_lahir)) * 12 +
   EXTRACT(MONTH FROM AGE(CURRENT_DATE, b.tanggal_lahir)))::INTEGER AS usia_bulan_sekarang,
  i.nama_imunisasi,
  i.jumlah_dosis_total,
  bi.dosis_ke,
  bi.tanggal_pemberian,
  bi.status_pemberian
FROM balita b
CROSS JOIN imunisasi i
LEFT JOIN balita_imunisasi bi
       ON bi.id_balita    = b.id_balita
      AND bi.id_imunisasi = i.id_imunisasi
WHERE b.status_aktif = TRUE
ORDER BY b.id_balita, i.id_imunisasi, bi.dosis_ke;

-- Stunting risk report — only flagged, active balita
CREATE VIEW v_stunting_risk AS
SELECT
  pos.nama_posyandu,
  b.id_balita,
  b.nama            AS nama_balita,
  b.jenis_kelamin,
  b.tanggal_lahir,
  o.nama            AS nama_ortu,
  o.no_hp           AS kontak_ortu,
  p.tanggal_ukur,
  p.usia_bulan,
  p.tinggi_badan,
  p.z_score_tb_u,
  p.tingkat_risiko,
  p.catatan
FROM pengukuran p
JOIN kunjungan k  ON k.id_kunjungan  = p.id_kunjungan
JOIN balita b     ON b.id_balita     = k.id_balita
JOIN orangtua o   ON o.id_ortu       = b.id_ortu
JOIN posyandu pos ON pos.id_posyandu = k.id_posyandu
WHERE p.flag_risiko_stunting = TRUE
  AND b.status_aktif         = TRUE
ORDER BY p.z_score_tb_u ASC, p.tanggal_ukur DESC;


-- ============================================================
-- SECTION 6: WHO STANDARD REFERENCE DATA (488 rows)
-- Source: WHO Child Growth Standards
-- standar_pertumbuhan.indeks:
--   BB/U, TB/U, LK/U → age in months (0–60)
--   BB/TB             → height in cm  (45–110)
-- ============================================================

-- ── BB/U Boys (0–60 months) ──────────────────────────────────
INSERT INTO standar_pertumbuhan (jenis_kelamin, indeks, tipe_metrik, nilai_l, nilai_m, nilai_s) VALUES
('Laki-laki',0,'BB/U',0.3487,3.3464,0.14602),('Laki-laki',1,'BB/U',0.2297,4.4709,0.13395),
('Laki-laki',2,'BB/U',0.1970,5.5675,0.12385),('Laki-laki',3,'BB/U',0.1738,6.3762,0.11727),
('Laki-laki',4,'BB/U',0.1553,7.0023,0.11316),('Laki-laki',5,'BB/U',0.1395,7.5105,0.11080),
('Laki-laki',6,'BB/U',0.1257,7.9340,0.10958),('Laki-laki',7,'BB/U',0.1134,8.2970,0.10902),
('Laki-laki',8,'BB/U',0.1021,8.6151,0.10882),('Laki-laki',9,'BB/U',0.0917,8.9014,0.10881),
('Laki-laki',10,'BB/U',0.0820,9.1649,0.10891),('Laki-laki',11,'BB/U',0.0730,9.4122,0.10906),
('Laki-laki',12,'BB/U',0.0644,9.6479,0.10925),('Laki-laki',13,'BB/U',0.0563,9.8749,0.10949),
('Laki-laki',14,'BB/U',0.0487,10.0953,0.10976),('Laki-laki',15,'BB/U',0.0413,10.3108,0.11007),
('Laki-laki',16,'BB/U',0.0343,10.5228,0.11041),('Laki-laki',17,'BB/U',0.0276,10.7319,0.11079),
('Laki-laki',18,'BB/U',0.0211,10.9385,0.11119),('Laki-laki',19,'BB/U',0.0148,11.1430,0.11164),
('Laki-laki',20,'BB/U',0.0087,11.3462,0.11211),('Laki-laki',21,'BB/U',0.0028,11.5486,0.11262),
('Laki-laki',22,'BB/U',-0.0030,11.7504,0.11316),('Laki-laki',23,'BB/U',-0.0086,11.9514,0.11374),
('Laki-laki',24,'BB/U',-0.0141,12.1515,0.11434),('Laki-laki',25,'BB/U',-0.0194,12.3502,0.11497),
('Laki-laki',26,'BB/U',-0.0246,12.5479,0.11563),('Laki-laki',27,'BB/U',-0.0296,12.7447,0.11632),
('Laki-laki',28,'BB/U',-0.0345,12.9405,0.11704),('Laki-laki',29,'BB/U',-0.0393,13.1353,0.11778),
('Laki-laki',30,'BB/U',-0.0439,13.3292,0.11855),('Laki-laki',31,'BB/U',-0.0484,13.5222,0.11935),
('Laki-laki',32,'BB/U',-0.0527,13.7144,0.12017),('Laki-laki',33,'BB/U',-0.0569,13.9057,0.12101),
('Laki-laki',34,'BB/U',-0.0610,14.0963,0.12188),('Laki-laki',35,'BB/U',-0.0649,14.2862,0.12276),
('Laki-laki',36,'BB/U',-0.0687,14.4753,0.12367),('Laki-laki',37,'BB/U',-0.0723,14.6638,0.12460),
('Laki-laki',38,'BB/U',-0.0759,14.8517,0.12555),('Laki-laki',39,'BB/U',-0.0793,15.0390,0.12651),
('Laki-laki',40,'BB/U',-0.0826,15.2257,0.12750),('Laki-laki',41,'BB/U',-0.0857,15.4119,0.12850),
('Laki-laki',42,'BB/U',-0.0888,15.5976,0.12952),('Laki-laki',43,'BB/U',-0.0917,15.7827,0.13056),
('Laki-laki',44,'BB/U',-0.0945,15.9674,0.13161),('Laki-laki',45,'BB/U',-0.0972,16.1516,0.13267),
('Laki-laki',46,'BB/U',-0.0998,16.3353,0.13375),('Laki-laki',47,'BB/U',-0.1023,16.5186,0.13485),
('Laki-laki',48,'BB/U',-0.1047,16.7014,0.13595),('Laki-laki',49,'BB/U',-0.1070,16.8838,0.13707),
('Laki-laki',50,'BB/U',-0.1092,17.0658,0.13820),('Laki-laki',51,'BB/U',-0.1113,17.2474,0.13934),
('Laki-laki',52,'BB/U',-0.1133,17.4286,0.14049),('Laki-laki',53,'BB/U',-0.1152,17.6094,0.14165),
('Laki-laki',54,'BB/U',-0.1171,17.7899,0.14282),('Laki-laki',55,'BB/U',-0.1188,17.9700,0.14400),
('Laki-laki',56,'BB/U',-0.1205,18.1497,0.14518),('Laki-laki',57,'BB/U',-0.1221,18.3291,0.14638),
('Laki-laki',58,'BB/U',-0.1236,18.5082,0.14758),('Laki-laki',59,'BB/U',-0.1251,18.6870,0.14879),
('Laki-laki',60,'BB/U',-0.1265,18.8655,0.15000);

-- ── BB/U Girls (0–60 months) ─────────────────────────────────
INSERT INTO standar_pertumbuhan (jenis_kelamin, indeks, tipe_metrik, nilai_l, nilai_m, nilai_s) VALUES
('Perempuan',0,'BB/U',0.3809,3.2322,0.14171),('Perempuan',1,'BB/U',0.1714,4.1873,0.13724),
('Perempuan',2,'BB/U',0.0962,5.1282,0.13000),('Perempuan',3,'BB/U',0.0402,5.8458,0.12619),
('Perempuan',4,'BB/U',-0.0050,6.4237,0.12402),('Perempuan',5,'BB/U',-0.0430,6.8985,0.12274),
('Perempuan',6,'BB/U',-0.0756,7.2970,0.12204),('Perempuan',7,'BB/U',-0.1039,7.6422,0.12178),
('Perempuan',8,'BB/U',-0.1288,7.9487,0.12181),('Perempuan',9,'BB/U',-0.1507,8.2254,0.12199),
('Perempuan',10,'BB/U',-0.1700,8.4800,0.12223),('Perempuan',11,'BB/U',-0.1872,8.7192,0.12247),
('Perempuan',12,'BB/U',-0.2024,8.9481,0.12268),('Perempuan',13,'BB/U',-0.2158,9.1699,0.12283),
('Perempuan',14,'BB/U',-0.2278,9.3868,0.12294),('Perempuan',15,'BB/U',-0.2384,9.6003,0.12299),
('Perempuan',16,'BB/U',-0.2478,9.8111,0.12303),('Perempuan',17,'BB/U',-0.2562,10.0200,0.12306),
('Perempuan',18,'BB/U',-0.2637,10.2273,0.12309),('Perempuan',19,'BB/U',-0.2703,10.4331,0.12315),
('Perempuan',20,'BB/U',-0.2762,10.6379,0.12323),('Perempuan',21,'BB/U',-0.2815,10.8420,0.12335),
('Perempuan',22,'BB/U',-0.2862,11.0455,0.12350),('Perempuan',23,'BB/U',-0.2903,11.2487,0.12369),
('Perempuan',24,'BB/U',-0.2941,11.4516,0.12393),('Perempuan',25,'BB/U',-0.2975,11.6543,0.12421),
('Perempuan',26,'BB/U',-0.3006,11.8569,0.12453),('Perempuan',27,'BB/U',-0.3034,12.0595,0.12490),
('Perempuan',28,'BB/U',-0.3059,12.2620,0.12532),('Perempuan',29,'BB/U',-0.3082,12.4646,0.12578),
('Perempuan',30,'BB/U',-0.3103,12.6673,0.12629),('Perempuan',31,'BB/U',-0.3122,12.8699,0.12685),
('Perempuan',32,'BB/U',-0.3140,13.0727,0.12745),('Perempuan',33,'BB/U',-0.3156,13.2755,0.12810),
('Perempuan',34,'BB/U',-0.3170,13.4784,0.12879),('Perempuan',35,'BB/U',-0.3183,13.6814,0.12952),
('Perempuan',36,'BB/U',-0.3195,13.8846,0.13030),('Perempuan',37,'BB/U',-0.3205,14.0878,0.13112),
('Perempuan',38,'BB/U',-0.3215,14.2912,0.13197),('Perempuan',39,'BB/U',-0.3223,14.4947,0.13287),
('Perempuan',40,'BB/U',-0.3230,14.6983,0.13381),('Perempuan',41,'BB/U',-0.3236,14.9020,0.13479),
('Perempuan',42,'BB/U',-0.3242,15.1058,0.13580),('Perempuan',43,'BB/U',-0.3246,15.3097,0.13686),
('Perempuan',44,'BB/U',-0.3250,15.5138,0.13795),('Perempuan',45,'BB/U',-0.3253,15.7179,0.13908),
('Perempuan',46,'BB/U',-0.3255,15.9221,0.14025),('Perempuan',47,'BB/U',-0.3257,16.1265,0.14145),
('Perempuan',48,'BB/U',-0.3259,16.3309,0.14269),('Perempuan',49,'BB/U',-0.3259,16.5355,0.14396),
('Perempuan',50,'BB/U',-0.3260,16.7401,0.14527),('Perempuan',51,'BB/U',-0.3260,16.9449,0.14661),
('Perempuan',52,'BB/U',-0.3259,17.1498,0.14798),('Perempuan',53,'BB/U',-0.3258,17.3548,0.14939),
('Perempuan',54,'BB/U',-0.3257,17.5599,0.15083),('Perempuan',55,'BB/U',-0.3256,17.7651,0.15230),
('Perempuan',56,'BB/U',-0.3254,17.9704,0.15380),('Perempuan',57,'BB/U',-0.3252,18.1758,0.15533),
('Perempuan',58,'BB/U',-0.3250,18.3813,0.15689),('Perempuan',59,'BB/U',-0.3248,18.5869,0.15849),
('Perempuan',60,'BB/U',-0.3246,18.7926,0.16011);

-- ── TB/U Boys (0–60 months) ──────────────────────────────────
INSERT INTO standar_pertumbuhan (jenis_kelamin, indeks, tipe_metrik, nilai_l, nilai_m, nilai_s) VALUES
('Laki-laki',0,'TB/U',1,49.8842,0.03795),('Laki-laki',1,'TB/U',1,54.7244,0.03557),
('Laki-laki',2,'TB/U',1,58.4249,0.03424),('Laki-laki',3,'TB/U',1,61.4292,0.03328),
('Laki-laki',4,'TB/U',1,63.8860,0.03257),('Laki-laki',5,'TB/U',1,65.9026,0.03204),
('Laki-laki',6,'TB/U',1,67.6236,0.03165),('Laki-laki',7,'TB/U',1,69.1645,0.03139),
('Laki-laki',8,'TB/U',1,70.5994,0.03124),('Laki-laki',9,'TB/U',1,71.9687,0.03117),
('Laki-laki',10,'TB/U',1,73.2812,0.03117),('Laki-laki',11,'TB/U',1,74.5388,0.03123),
('Laki-laki',12,'TB/U',1,75.7488,0.03133),('Laki-laki',13,'TB/U',1,76.9186,0.03147),
('Laki-laki',14,'TB/U',1,78.0497,0.03164),('Laki-laki',15,'TB/U',1,79.1458,0.03184),
('Laki-laki',16,'TB/U',1,80.2113,0.03207),('Laki-laki',17,'TB/U',1,81.2487,0.03231),
('Laki-laki',18,'TB/U',1,82.2587,0.03257),('Laki-laki',19,'TB/U',1,83.2418,0.03285),
('Laki-laki',20,'TB/U',1,84.1996,0.03313),('Laki-laki',21,'TB/U',1,85.1348,0.03342),
('Laki-laki',22,'TB/U',1,86.0477,0.03372),('Laki-laki',23,'TB/U',1,86.9393,0.03402),
('Laki-laki',24,'TB/U',1,87.8161,0.03432),('Laki-laki',25,'TB/U',1,88.6762,0.03462),
('Laki-laki',26,'TB/U',1,89.5215,0.03492),('Laki-laki',27,'TB/U',1,90.3534,0.03522),
('Laki-laki',28,'TB/U',1,91.1726,0.03551),('Laki-laki',29,'TB/U',1,91.9801,0.03580),
('Laki-laki',30,'TB/U',1,92.7767,0.03609),('Laki-laki',31,'TB/U',1,93.5631,0.03637),
('Laki-laki',32,'TB/U',1,94.3399,0.03665),('Laki-laki',33,'TB/U',1,95.1078,0.03693),
('Laki-laki',34,'TB/U',1,95.8673,0.03720),('Laki-laki',35,'TB/U',1,96.6188,0.03746),
('Laki-laki',36,'TB/U',1,97.3626,0.03773),('Laki-laki',37,'TB/U',1,98.0991,0.03798),
('Laki-laki',38,'TB/U',1,98.8288,0.03824),('Laki-laki',39,'TB/U',1,99.5519,0.03849),
('Laki-laki',40,'TB/U',1,100.2688,0.03873),('Laki-laki',41,'TB/U',1,100.9797,0.03897),
('Laki-laki',42,'TB/U',1,101.6850,0.03921),('Laki-laki',43,'TB/U',1,102.3849,0.03944),
('Laki-laki',44,'TB/U',1,103.0796,0.03967),('Laki-laki',45,'TB/U',1,103.7695,0.03989),
('Laki-laki',46,'TB/U',1,104.4547,0.04011),('Laki-laki',47,'TB/U',1,105.1354,0.04033),
('Laki-laki',48,'TB/U',1,105.8118,0.04054),('Laki-laki',49,'TB/U',1,106.4841,0.04075),
('Laki-laki',50,'TB/U',1,107.1525,0.04096),('Laki-laki',51,'TB/U',1,107.8170,0.04116),
('Laki-laki',52,'TB/U',1,108.4779,0.04136),('Laki-laki',53,'TB/U',1,109.1352,0.04156),
('Laki-laki',54,'TB/U',1,109.7891,0.04175),('Laki-laki',55,'TB/U',1,110.4396,0.04194),
('Laki-laki',56,'TB/U',1,111.0869,0.04213),('Laki-laki',57,'TB/U',1,111.7311,0.04232),
('Laki-laki',58,'TB/U',1,112.3723,0.04250),('Laki-laki',59,'TB/U',1,113.0105,0.04268),
('Laki-laki',60,'TB/U',1,113.6459,0.04286);

-- ── TB/U Girls (0–60 months) ─────────────────────────────────
INSERT INTO standar_pertumbuhan (jenis_kelamin, indeks, tipe_metrik, nilai_l, nilai_m, nilai_s) VALUES
('Perempuan',0,'TB/U',1,49.1477,0.03790),('Perempuan',1,'TB/U',1,53.6872,0.03640),
('Perempuan',2,'TB/U',1,57.0673,0.03568),('Perempuan',3,'TB/U',1,59.8029,0.03496),
('Perempuan',4,'TB/U',1,62.0899,0.03438),('Perempuan',5,'TB/U',1,64.0301,0.03391),
('Perempuan',6,'TB/U',1,65.7311,0.03353),('Perempuan',7,'TB/U',1,67.2873,0.03325),
('Perempuan',8,'TB/U',1,68.7498,0.03306),('Perempuan',9,'TB/U',1,70.1435,0.03295),
('Perempuan',10,'TB/U',1,71.4818,0.03290),('Perempuan',11,'TB/U',1,72.7710,0.03292),
('Perempuan',12,'TB/U',1,74.0150,0.03298),('Perempuan',13,'TB/U',1,75.2176,0.03306),
('Perempuan',14,'TB/U',1,76.3817,0.03317),('Perempuan',15,'TB/U',1,77.5099,0.03330),
('Perempuan',16,'TB/U',1,78.6055,0.03345),('Perempuan',17,'TB/U',1,79.6710,0.03362),
('Perempuan',18,'TB/U',1,80.7079,0.03380),('Perempuan',19,'TB/U',1,81.7182,0.03400),
('Perempuan',20,'TB/U',1,82.7036,0.03420),('Perempuan',21,'TB/U',1,83.6654,0.03441),
('Perempuan',22,'TB/U',1,84.6040,0.03463),('Perempuan',23,'TB/U',1,85.5202,0.03485),
('Perempuan',24,'TB/U',1,86.4153,0.03508),('Perempuan',25,'TB/U',1,87.2897,0.03531),
('Perempuan',26,'TB/U',1,88.1443,0.03555),('Perempuan',27,'TB/U',1,88.9798,0.03578),
('Perempuan',28,'TB/U',1,89.7968,0.03602),('Perempuan',29,'TB/U',1,90.5958,0.03626),
('Perempuan',30,'TB/U',1,91.3775,0.03650),('Perempuan',31,'TB/U',1,92.1424,0.03674),
('Perempuan',32,'TB/U',1,92.8911,0.03698),('Perempuan',33,'TB/U',1,93.6239,0.03722),
('Perempuan',34,'TB/U',1,94.3414,0.03746),('Perempuan',35,'TB/U',1,95.0438,0.03770),
('Perempuan',36,'TB/U',1,95.7316,0.03793),('Perempuan',37,'TB/U',1,96.4051,0.03817),
('Perempuan',38,'TB/U',1,97.0647,0.03840),('Perempuan',39,'TB/U',1,97.7107,0.03863),
('Perempuan',40,'TB/U',1,98.3435,0.03886),('Perempuan',41,'TB/U',1,98.9633,0.03908),
('Perempuan',42,'TB/U',1,99.5705,0.03931),('Perempuan',43,'TB/U',1,100.1653,0.03953),
('Perempuan',44,'TB/U',1,100.7480,0.03975),('Perempuan',45,'TB/U',1,101.3189,0.03997),
('Perempuan',46,'TB/U',1,101.8782,0.04019),('Perempuan',47,'TB/U',1,102.4262,0.04040),
('Perempuan',48,'TB/U',1,102.9631,0.04061),('Perempuan',49,'TB/U',1,103.4891,0.04083),
('Perempuan',50,'TB/U',1,104.0045,0.04104),('Perempuan',51,'TB/U',1,104.5094,0.04125),
('Perempuan',52,'TB/U',1,105.0041,0.04145),('Perempuan',53,'TB/U',1,105.4888,0.04166),
('Perempuan',54,'TB/U',1,105.9635,0.04186),('Perempuan',55,'TB/U',1,106.4286,0.04207),
('Perempuan',56,'TB/U',1,106.8841,0.04227),('Perempuan',57,'TB/U',1,107.3303,0.04247),
('Perempuan',58,'TB/U',1,107.7673,0.04267),('Perempuan',59,'TB/U',1,108.1952,0.04287),
('Perempuan',60,'TB/U',1,108.6143,0.04307);

-- ── BB/TB Boys (45–110 cm) ───────────────────────────────────
INSERT INTO standar_pertumbuhan (jenis_kelamin, indeks, tipe_metrik, nilai_l, nilai_m, nilai_s) VALUES
('Laki-laki',45,'BB/TB',1.3666,2.4416,0.09182),('Laki-laki',46,'BB/TB',1.3594,2.5298,0.09153),
('Laki-laki',47,'BB/TB',1.3522,2.6216,0.09139),('Laki-laki',48,'BB/TB',1.3450,2.7169,0.09139),
('Laki-laki',49,'BB/TB',1.3378,2.8155,0.09152),('Laki-laki',50,'BB/TB',1.3306,2.9174,0.09178),
('Laki-laki',51,'BB/TB',1.3234,3.0224,0.09216),('Laki-laki',52,'BB/TB',1.3162,3.1303,0.09266),
('Laki-laki',53,'BB/TB',1.3090,3.2411,0.09326),('Laki-laki',54,'BB/TB',1.3018,3.3547,0.09396),
('Laki-laki',55,'BB/TB',1.2946,3.4709,0.09475),('Laki-laki',56,'BB/TB',1.2874,3.5897,0.09562),
('Laki-laki',57,'BB/TB',1.2802,3.7108,0.09657),('Laki-laki',58,'BB/TB',1.2730,3.8343,0.09759),
('Laki-laki',59,'BB/TB',1.2658,3.9600,0.09867),('Laki-laki',60,'BB/TB',1.2586,4.0878,0.09981),
('Laki-laki',61,'BB/TB',1.2514,4.2176,0.10100),('Laki-laki',62,'BB/TB',1.2442,4.3493,0.10224),
('Laki-laki',63,'BB/TB',1.2370,4.4828,0.10352),('Laki-laki',64,'BB/TB',1.2298,4.6179,0.10484),
('Laki-laki',65,'BB/TB',1.2226,4.7547,0.10619),('Laki-laki',66,'BB/TB',1.2154,4.8929,0.10757),
('Laki-laki',67,'BB/TB',1.2082,5.0325,0.10898),('Laki-laki',68,'BB/TB',1.2010,5.1734,0.11041),
('Laki-laki',69,'BB/TB',1.1938,5.3155,0.11186),('Laki-laki',70,'BB/TB',1.1866,5.4587,0.11333),
('Laki-laki',71,'BB/TB',1.1794,5.6029,0.11481),('Laki-laki',72,'BB/TB',1.1722,5.7481,0.11630),
('Laki-laki',73,'BB/TB',1.1650,5.8941,0.11780),('Laki-laki',74,'BB/TB',1.1578,6.0410,0.11930),
('Laki-laki',75,'BB/TB',1.1506,6.1886,0.12080),('Laki-laki',76,'BB/TB',1.1434,6.3369,0.12230),
('Laki-laki',77,'BB/TB',1.1362,6.4858,0.12379),('Laki-laki',78,'BB/TB',1.1290,6.6353,0.12528),
('Laki-laki',79,'BB/TB',1.1218,6.7853,0.12676),('Laki-laki',80,'BB/TB',1.1146,6.9358,0.12823),
('Laki-laki',81,'BB/TB',1.1074,7.0867,0.12969),('Laki-laki',82,'BB/TB',1.1002,7.2380,0.13113),
('Laki-laki',83,'BB/TB',1.0930,7.3896,0.13256),('Laki-laki',84,'BB/TB',1.0858,7.5415,0.13398),
('Laki-laki',85,'BB/TB',1.0786,7.6937,0.13537),('Laki-laki',86,'BB/TB',1.0714,7.8461,0.13675),
('Laki-laki',87,'BB/TB',1.0642,7.9987,0.13811),('Laki-laki',88,'BB/TB',1.0570,8.1514,0.13945),
('Laki-laki',89,'BB/TB',1.0498,8.3043,0.14077),('Laki-laki',90,'BB/TB',1.0426,8.4573,0.14207),
('Laki-laki',91,'BB/TB',1.0354,8.6103,0.14335),('Laki-laki',92,'BB/TB',1.0282,8.7634,0.14460),
('Laki-laki',93,'BB/TB',1.0210,8.9165,0.14584),('Laki-laki',94,'BB/TB',1.0138,9.0696,0.14705),
('Laki-laki',95,'BB/TB',1.0066,9.2227,0.14823),('Laki-laki',96,'BB/TB',0.9994,9.3757,0.14940),
('Laki-laki',97,'BB/TB',0.9922,9.5287,0.15054),('Laki-laki',98,'BB/TB',0.9850,9.6816,0.15166),
('Laki-laki',99,'BB/TB',0.9778,9.8344,0.15276),('Laki-laki',100,'BB/TB',0.9706,9.9871,0.15383),
('Laki-laki',101,'BB/TB',0.9634,10.1397,0.15488),('Laki-laki',102,'BB/TB',0.9562,10.2922,0.15591),
('Laki-laki',103,'BB/TB',0.9490,10.4446,0.15692),('Laki-laki',104,'BB/TB',0.9418,10.5968,0.15790),
('Laki-laki',105,'BB/TB',0.9346,10.7489,0.15886),('Laki-laki',106,'BB/TB',0.9274,10.9009,0.15980),
('Laki-laki',107,'BB/TB',0.9202,11.0527,0.16072),('Laki-laki',108,'BB/TB',0.9130,11.2043,0.16162),
('Laki-laki',109,'BB/TB',0.9058,11.3558,0.16250),('Laki-laki',110,'BB/TB',0.8986,11.5071,0.16336);

-- ── BB/TB Girls (45–110 cm) ──────────────────────────────────
INSERT INTO standar_pertumbuhan (jenis_kelamin, indeks, tipe_metrik, nilai_l, nilai_m, nilai_s) VALUES
('Perempuan',45,'BB/TB',1.3809,2.3685,0.09417),('Perempuan',46,'BB/TB',1.3738,2.4539,0.09396),
('Perempuan',47,'BB/TB',1.3666,2.5429,0.09387),('Perempuan',48,'BB/TB',1.3594,2.6352,0.09391),
('Perempuan',49,'BB/TB',1.3522,2.7308,0.09407),('Perempuan',50,'BB/TB',1.3450,2.8294,0.09435),
('Perempuan',51,'BB/TB',1.3378,2.9310,0.09474),('Perempuan',52,'BB/TB',1.3306,3.0354,0.09523),
('Perempuan',53,'BB/TB',1.3234,3.1425,0.09582),('Perempuan',54,'BB/TB',1.3162,3.2521,0.09650),
('Perempuan',55,'BB/TB',1.3090,3.3641,0.09727),('Perempuan',56,'BB/TB',1.3018,3.4784,0.09812),
('Perempuan',57,'BB/TB',1.2946,3.5949,0.09904),('Perempuan',58,'BB/TB',1.2874,3.7134,0.10003),
('Perempuan',59,'BB/TB',1.2802,3.8339,0.10109),('Perempuan',60,'BB/TB',1.2730,3.9562,0.10220),
('Perempuan',61,'BB/TB',1.2658,4.0802,0.10337),('Perempuan',62,'BB/TB',1.2586,4.2058,0.10459),
('Perempuan',63,'BB/TB',1.2514,4.3329,0.10586),('Perempuan',64,'BB/TB',1.2442,4.4614,0.10717),
('Perempuan',65,'BB/TB',1.2370,4.5912,0.10852),('Perempuan',66,'BB/TB',1.2298,4.7222,0.10990),
('Perempuan',67,'BB/TB',1.2226,4.8543,0.11132),('Perempuan',68,'BB/TB',1.2154,4.9874,0.11276),
('Perempuan',69,'BB/TB',1.2082,5.1214,0.11423),('Perempuan',70,'BB/TB',1.2010,5.2562,0.11572),
('Perempuan',71,'BB/TB',1.1938,5.3918,0.11723),('Perempuan',72,'BB/TB',1.1866,5.5280,0.11875),
('Perempuan',73,'BB/TB',1.1794,5.6648,0.12029),('Perempuan',74,'BB/TB',1.1722,5.8021,0.12184),
('Perempuan',75,'BB/TB',1.1650,5.9398,0.12340),('Perempuan',76,'BB/TB',1.1578,6.0779,0.12497),
('Perempuan',77,'BB/TB',1.1506,6.2163,0.12654),('Perempuan',78,'BB/TB',1.1434,6.3550,0.12811),
('Perempuan',79,'BB/TB',1.1362,6.4939,0.12968),('Perempuan',80,'BB/TB',1.1290,6.6330,0.13125),
('Perempuan',81,'BB/TB',1.1218,6.7722,0.13282),('Perempuan',82,'BB/TB',1.1146,6.9115,0.13437),
('Perempuan',83,'BB/TB',1.1074,7.0509,0.13592),('Perempuan',84,'BB/TB',1.1002,7.1903,0.13746),
('Perempuan',85,'BB/TB',1.0930,7.3296,0.13899),('Perempuan',86,'BB/TB',1.0858,7.4689,0.14050),
('Perempuan',87,'BB/TB',1.0786,7.6081,0.14200),('Perempuan',88,'BB/TB',1.0714,7.7472,0.14349),
('Perempuan',89,'BB/TB',1.0642,7.8861,0.14496),('Perempuan',90,'BB/TB',1.0570,8.0248,0.14641),
('Perempuan',91,'BB/TB',1.0498,8.1634,0.14785),('Perempuan',92,'BB/TB',1.0426,8.3017,0.14927),
('Perempuan',93,'BB/TB',1.0354,8.4398,0.15067),('Perempuan',94,'BB/TB',1.0282,8.5777,0.15205),
('Perempuan',95,'BB/TB',1.0210,8.7153,0.15342),('Perempuan',96,'BB/TB',1.0138,8.8527,0.15476),
('Perempuan',97,'BB/TB',1.0066,8.9898,0.15609),('Perempuan',98,'BB/TB',0.9994,9.1266,0.15740),
('Perempuan',99,'BB/TB',0.9922,9.2632,0.15869),('Perempuan',100,'BB/TB',0.9850,9.3995,0.15996),
('Perempuan',101,'BB/TB',0.9778,9.5355,0.16121),('Perempuan',102,'BB/TB',0.9706,9.6712,0.16245),
('Perempuan',103,'BB/TB',0.9634,9.8066,0.16366),('Perempuan',104,'BB/TB',0.9562,9.9417,0.16486),
('Perempuan',105,'BB/TB',0.9490,10.0765,0.16604),('Perempuan',106,'BB/TB',0.9418,10.2110,0.16720),
('Perempuan',107,'BB/TB',0.9346,10.3451,0.16834),('Perempuan',108,'BB/TB',0.9274,10.4790,0.16947),
('Perempuan',109,'BB/TB',0.9202,10.6125,0.17057),('Perempuan',110,'BB/TB',0.9130,10.7457,0.17166);

-- ── LK/U Boys (0–60 months) ──────────────────────────────────
INSERT INTO standar_pertumbuhan (jenis_kelamin, indeks, tipe_metrik, nilai_l, nilai_m, nilai_s) VALUES
('Laki-laki',0,'LK/U',1,34.4618,0.03686),('Laki-laki',1,'LK/U',1,37.2759,0.03254),
('Laki-laki',2,'LK/U',1,39.1285,0.03039),('Laki-laki',3,'LK/U',1,40.5135,0.02915),
('Laki-laki',4,'LK/U',1,41.6317,0.02834),('Laki-laki',5,'LK/U',1,42.5576,0.02776),
('Laki-laki',6,'LK/U',1,43.3306,0.02734),('Laki-laki',7,'LK/U',1,43.9803,0.02703),
('Laki-laki',8,'LK/U',1,44.5299,0.02681),('Laki-laki',9,'LK/U',1,44.9998,0.02664),
('Laki-laki',10,'LK/U',1,45.4044,0.02651),('Laki-laki',11,'LK/U',1,45.7557,0.02641),
('Laki-laki',12,'LK/U',1,46.0630,0.02635),('Laki-laki',13,'LK/U',1,46.3346,0.02631),
('Laki-laki',14,'LK/U',1,46.5768,0.02628),('Laki-laki',15,'LK/U',1,46.7952,0.02628),
('Laki-laki',16,'LK/U',1,46.9944,0.02629),('Laki-laki',17,'LK/U',1,47.1783,0.02631),
('Laki-laki',18,'LK/U',1,47.3497,0.02634),('Laki-laki',19,'LK/U',1,47.5112,0.02638),
('Laki-laki',20,'LK/U',1,47.6645,0.02643),('Laki-laki',21,'LK/U',1,47.8110,0.02648),
('Laki-laki',22,'LK/U',1,47.9520,0.02654),('Laki-laki',23,'LK/U',1,48.0884,0.02660),
('Laki-laki',24,'LK/U',1,48.2209,0.02667),('Laki-laki',25,'LK/U',1,48.3501,0.02674),
('Laki-laki',26,'LK/U',1,48.4765,0.02681),('Laki-laki',27,'LK/U',1,48.6005,0.02688),
('Laki-laki',28,'LK/U',1,48.7224,0.02696),('Laki-laki',29,'LK/U',1,48.8426,0.02704),
('Laki-laki',30,'LK/U',1,48.9612,0.02712),('Laki-laki',31,'LK/U',1,49.0785,0.02720),
('Laki-laki',32,'LK/U',1,49.1948,0.02728),('Laki-laki',33,'LK/U',1,49.3100,0.02736),
('Laki-laki',34,'LK/U',1,49.4245,0.02744),('Laki-laki',35,'LK/U',1,49.5383,0.02752),
('Laki-laki',36,'LK/U',1,49.6516,0.02760),('Laki-laki',37,'LK/U',1,49.7644,0.02768),
('Laki-laki',38,'LK/U',1,49.8769,0.02776),('Laki-laki',39,'LK/U',1,49.9891,0.02784),
('Laki-laki',40,'LK/U',1,50.1011,0.02792),('Laki-laki',41,'LK/U',1,50.2129,0.02800),
('Laki-laki',42,'LK/U',1,50.3246,0.02808),('Laki-laki',43,'LK/U',1,50.4363,0.02816),
('Laki-laki',44,'LK/U',1,50.5479,0.02824),('Laki-laki',45,'LK/U',1,50.6594,0.02832),
('Laki-laki',46,'LK/U',1,50.7710,0.02840),('Laki-laki',47,'LK/U',1,50.8826,0.02847),
('Laki-laki',48,'LK/U',1,50.9942,0.02855),('Laki-laki',49,'LK/U',1,51.1058,0.02863),
('Laki-laki',50,'LK/U',1,51.2175,0.02871),('Laki-laki',51,'LK/U',1,51.3293,0.02878),
('Laki-laki',52,'LK/U',1,51.4411,0.02886),('Laki-laki',53,'LK/U',1,51.5530,0.02893),
('Laki-laki',54,'LK/U',1,51.6649,0.02901),('Laki-laki',55,'LK/U',1,51.7770,0.02908),
('Laki-laki',56,'LK/U',1,51.8891,0.02916),('Laki-laki',57,'LK/U',1,52.0013,0.02923),
('Laki-laki',58,'LK/U',1,52.1136,0.02930),('Laki-laki',59,'LK/U',1,52.2259,0.02938),
('Laki-laki',60,'LK/U',1,52.3384,0.02945);

-- ── LK/U Girls (0–60 months) ─────────────────────────────────
INSERT INTO standar_pertumbuhan (jenis_kelamin, indeks, tipe_metrik, nilai_l, nilai_m, nilai_s) VALUES
('Perempuan',0,'LK/U',1,33.8787,0.03496),('Perempuan',1,'LK/U',1,36.5463,0.03203),
('Perempuan',2,'LK/U',1,38.2521,0.03029),('Perempuan',3,'LK/U',1,39.5328,0.02923),
('Perempuan',4,'LK/U',1,40.5817,0.02850),('Perempuan',5,'LK/U',1,41.4592,0.02797),
('Perempuan',6,'LK/U',1,42.2009,0.02758),('Perempuan',7,'LK/U',1,42.8299,0.02729),
('Perempuan',8,'LK/U',1,43.3674,0.02708),('Perempuan',9,'LK/U',1,43.8298,0.02692),
('Perempuan',10,'LK/U',1,44.2306,0.02680),('Perempuan',11,'LK/U',1,44.5803,0.02672),
('Perempuan',12,'LK/U',1,44.8876,0.02666),('Perempuan',13,'LK/U',1,45.1594,0.02663),
('Perempuan',14,'LK/U',1,45.4019,0.02661),('Perempuan',15,'LK/U',1,45.6202,0.02661),
('Perempuan',16,'LK/U',1,45.8185,0.02662),('Perempuan',17,'LK/U',1,46.0003,0.02664),
('Perempuan',18,'LK/U',1,46.1687,0.02667),('Perempuan',19,'LK/U',1,46.3259,0.02671),
('Perempuan',20,'LK/U',1,46.4738,0.02676),('Perempuan',21,'LK/U',1,46.6141,0.02681),
('Perempuan',22,'LK/U',1,46.7479,0.02687),('Perempuan',23,'LK/U',1,46.8763,0.02693),
('Perempuan',24,'LK/U',1,47.0001,0.02699),('Perempuan',25,'LK/U',1,47.1200,0.02706),
('Perempuan',26,'LK/U',1,47.2366,0.02713),('Perempuan',27,'LK/U',1,47.3504,0.02720),
('Perempuan',28,'LK/U',1,47.4618,0.02727),('Perempuan',29,'LK/U',1,47.5711,0.02735),
('Perempuan',30,'LK/U',1,47.6786,0.02742),('Perempuan',31,'LK/U',1,47.7845,0.02750),
('Perempuan',32,'LK/U',1,47.8891,0.02758),('Perempuan',33,'LK/U',1,47.9925,0.02766),
('Perempuan',34,'LK/U',1,48.0948,0.02774),('Perempuan',35,'LK/U',1,48.1963,0.02782),
('Perempuan',36,'LK/U',1,48.2970,0.02790),('Perempuan',37,'LK/U',1,48.3970,0.02798),
('Perempuan',38,'LK/U',1,48.4964,0.02806),('Perempuan',39,'LK/U',1,48.5953,0.02814),
('Perempuan',40,'LK/U',1,48.6938,0.02822),('Perempuan',41,'LK/U',1,48.7919,0.02830),
('Perempuan',42,'LK/U',1,48.8898,0.02838),('Perempuan',43,'LK/U',1,48.9874,0.02846),
('Perempuan',44,'LK/U',1,49.0849,0.02854),('Perempuan',45,'LK/U',1,49.1822,0.02862),
('Perempuan',46,'LK/U',1,49.2794,0.02870),('Perempuan',47,'LK/U',1,49.3766,0.02878),
('Perempuan',48,'LK/U',1,49.4738,0.02886),('Perempuan',49,'LK/U',1,49.5709,0.02894),
('Perempuan',50,'LK/U',1,49.6681,0.02902),('Perempuan',51,'LK/U',1,49.7654,0.02909),
('Perempuan',52,'LK/U',1,49.8627,0.02917),('Perempuan',53,'LK/U',1,49.9601,0.02925),
('Perempuan',54,'LK/U',1,50.0576,0.02933),('Perempuan',55,'LK/U',1,50.1552,0.02940),
('Perempuan',56,'LK/U',1,50.2530,0.02948),('Perempuan',57,'LK/U',1,50.3509,0.02956),
('Perempuan',58,'LK/U',1,50.4489,0.02963),('Perempuan',59,'LK/U',1,50.5471,0.02971),
('Perempuan',60,'LK/U',1,50.6454,0.02978);


-- ============================================================
-- SECTION 7: SEED DATA
-- ============================================================

-- ── Kader ────────────────────────────────────────────────────
INSERT INTO kader (nama, no_hp) VALUES
('Siti Rahayu',   '081234567001'),
('Dewi Kartika',  '081234567002'),
('Rina Susanti',  '081234567003'),
('Yuni Astuti',   '081234567004'),
('Niken Permata', '081234567005');

-- ── Posyandu ─────────────────────────────────────────────────
INSERT INTO posyandu (nama_posyandu, lokasi) VALUES
('Posyandu Mawar',  'Jl. Mawar No.12, Kel. Keputih, Surabaya'),
('Posyandu Melati', 'Jl. Melati No.5, Kel. Gebang Putih, Surabaya');

-- ── Imunisasi ────────────────────────────────────────────────
INSERT INTO imunisasi (nama_imunisasi, usia_target, jumlah_dosis_total, interval_minimum_hari, is_mandatory) VALUES
('Hepatitis B',    '0 bulan',    3, 28,   TRUE),
('BCG',            '1 bulan',    1, NULL, TRUE),
('Polio',          '1-4 bulan',  4, 28,   TRUE),
('DPT-HB-Hib',    '2-4 bulan',  3, 28,   TRUE),
('Campak-Rubella', '9 bulan',    2, 180,  TRUE),
('IPV',            '4 bulan',    1, NULL, TRUE),
('PCV',            '2-12 bulan', 3, 56,   FALSE),
('Rotavirus',      '2-4 bulan',  2, 28,   FALSE);

-- ── Orangtua ─────────────────────────────────────────────────
INSERT INTO orangtua (nama, no_hp, alamat) VALUES
('Budi Santoso',     '082100000101', 'Jl. Keputih Tegal No.3, Surabaya'),
('Ahmad Fauzi',      '082100000102', 'Jl. Arief Rahman No.7, Surabaya'),
('Hendra Wijaya',    '082100000103', 'Jl. Semolowaru No.14, Surabaya'),
('Slamet Riyadi',    '082100000104', 'Jl. Medokan Ayu No.2, Surabaya'),
('Doni Prasetyo',    '082100000105', 'Jl. Rungkut Industri No.9, Surabaya'),
('Eko Wahyudi',      '082100000106', 'Jl. Penjaringan Sari No.6, Surabaya'),
('Rizki Firmansyah', '082100000107', 'Jl. Gebang Lor No.11, Surabaya'),
('Agus Setiawan',    '082100000108', 'Jl. Kejawan Putih No.4, Surabaya'),
('Fajar Nugroho',    '082100000109', 'Jl. Klampis Ngasem No.8, Surabaya'),
('Irwan Hidayat',    '082100000110', 'Jl. Arief Rahman No.22, Surabaya'),
('Wawan Kurniawan',  '082100000111', 'Jl. Semolowaru Indah No.1, Surabaya'),
('Bambang Susilo',   '082100000112', 'Jl. Keputih No.19, Surabaya'),
('Dedi Gunawan',     '082100000113', 'Jl. Medokan Semampir No.5, Surabaya'),
('Rudi Hartono',     '082100000114', 'Jl. Rungkut Harapan No.3, Surabaya'),
('Yusuf Effendi',    '082100000115', 'Jl. Gebang Putih No.17, Surabaya');

-- ── Balita ───────────────────────────────────────────────────
INSERT INTO balita (id_ortu, nama, tanggal_lahir, jenis_kelamin, alamat, berat_lahir, panjang_lahir, golongan_darah, tanggal_registrasi) VALUES
(1,  'Bintang Putra S.',   '2022-01-10', 'Laki-laki',  'Jl. Keputih Tegal No.3',    3.2, 49.0, 'O',  '2022-02-01'),
(2,  'Nayla Putri F.',     '2022-06-20', 'Perempuan',  'Jl. Arief Rahman No.7',      3.0, 48.5, 'A',  '2022-07-01'),
(3,  'Rizky Aditya W.',    '2021-09-15', 'Laki-laki',  'Jl. Semolowaru No.14',       3.5, 50.0, 'B',  '2021-10-01'),
(4,  'Safa Aulia R.',      '2022-03-01', 'Perempuan',  'Jl. Medokan Ayu No.2',       2.9, 47.5, 'AB', '2022-03-15'),
(5,  'Daffa Arkan P.',     '2021-11-25', 'Laki-laki',  'Jl. Rungkut Industri No.9',  3.3, 49.5, 'O',  '2021-12-10'),
(6,  'Keysha Almira W.',   '2022-08-10', 'Perempuan',  'Jl. Penjaringan Sari No.6',  3.1, 48.0, 'A',  '2022-09-01'),
(7,  'Gibran Rizki F.',    '2022-02-14', 'Laki-laki',  'Jl. Gebang Lor No.11',       3.4, 50.5, 'B',  '2022-03-01'),
(8,  'Nadia Salsabila S.', '2021-07-05', 'Perempuan',  'Jl. Kejawan Putih No.4',     2.8, 47.0, 'O',  '2021-08-01'),
(9,  'Farhan Maulana N.',  '2022-05-20', 'Laki-laki',  'Jl. Klampis Ngasem No.8',    3.6, 51.0, 'A',  '2022-06-01'),
(10, 'Rania Zahra H.',     '2022-10-30', 'Perempuan',  'Jl. Arief Rahman No.22',     3.0, 48.0, 'B',  '2022-11-15'),
(11, 'Arkan Dwi K.',       '2021-04-12', 'Laki-laki',  'Jl. Semolowaru Indah No.1',  3.2, 49.5, 'O',  '2021-05-01'),
(12, 'Azalea Putri S.',    '2022-09-08', 'Perempuan',  'Jl. Keputih No.19',           2.7, 46.5, 'A',  '2022-10-01'),
(13, 'Habibi Nurul D.',    '2021-06-17', 'Laki-laki',  'Jl. Medokan Semampir No.5',  3.1, 49.0, 'AB', '2021-07-01'),
(14, 'Camila Eka R.',      '2022-04-25', 'Perempuan',  'Jl. Rungkut Harapan No.3',   3.3, 49.0, 'O',  '2022-05-10'),
(15, 'Zafran Ilham Y.',    '2021-12-01', 'Laki-laki',  'Jl. Gebang Putih No.17',     3.0, 48.5, 'B',  '2021-12-20');

-- Partial NIK data (column is nullable; only some children have it)
UPDATE balita SET nik = '3578010110220001' WHERE id_balita = 1;
UPDATE balita SET nik = '3578010620220002' WHERE id_balita = 2;
UPDATE balita SET nik = '3578011509210003' WHERE id_balita = 3;

-- Soft-delete one child (moved away) to demonstrate status_aktif functionality
UPDATE balita
SET status_aktif  = FALSE,
    tanggal_keluar = '2024-09-01',
    alasan_keluar  = 'Pindah domisili ke Malang'
WHERE id_balita = 13;

-- ── Kunjungan + Pengukuran (3 visits per child) ──────────────
-- The z-score trigger fires on each pengukuran INSERT.
-- usia_bulan placeholder = 0; trigger overwrites with correct derived value.
DO $$
DECLARE
  v_data JSONB[] := ARRAY[
    '{"b":1, "p":1,"k":1,"d1":"2024-01-15","bb1":9.8, "tb1":79.0,"lk1":46.2,"bb2":10.5,"tb2":82.0,"lk2":46.8,"bb3":11.1,"tb3":84.5,"lk3":47.1}'::jsonb,
    '{"b":2, "p":1,"k":2,"d1":"2024-01-15","bb1":8.2, "tb1":73.0,"lk1":45.5,"bb2":8.9, "tb2":76.0,"lk2":46.0,"bb3":9.5, "tb3":78.5,"lk3":46.5}'::jsonb,
    '{"b":3, "p":1,"k":1,"d1":"2024-01-20","bb1":10.2,"tb1":82.0,"lk1":47.0,"bb2":10.8,"tb2":84.5,"lk2":47.4,"bb3":11.4,"tb3":87.0,"lk3":47.8}'::jsonb,
    '{"b":4, "p":2,"k":3,"d1":"2024-02-01","bb1":8.5, "tb1":74.0,"lk1":45.8,"bb2":9.0, "tb2":77.0,"lk2":46.2,"bb3":9.6, "tb3":79.5,"lk3":46.6}'::jsonb,
    '{"b":5, "p":1,"k":2,"d1":"2024-01-20","bb1":9.5, "tb1":80.5,"lk1":46.5,"bb2":10.2,"tb2":83.0,"lk2":47.0,"bb3":10.9,"tb3":86.0,"lk3":47.5}'::jsonb,
    '{"b":6, "p":2,"k":4,"d1":"2024-02-10","bb1":7.4, "tb1":68.5,"lk1":44.8,"bb2":8.0, "tb2":71.5,"lk2":45.3,"bb3":8.6, "tb3":74.0,"lk3":45.8}'::jsonb,
    '{"b":7, "p":1,"k":1,"d1":"2024-01-15","bb1":9.2, "tb1":78.0,"lk1":45.9,"bb2":9.9, "tb2":81.0,"lk2":46.5,"bb3":10.5,"tb3":83.5,"lk3":47.0}'::jsonb,
    '{"b":8, "p":2,"k":5,"d1":"2024-01-25","bb1":9.8, "tb1":75.0,"lk1":46.8,"bb2":10.3,"tb2":78.0,"lk2":47.2,"bb3":10.8,"tb3":80.5,"lk3":47.6}'::jsonb,
    '{"b":9, "p":1,"k":3,"d1":"2024-02-05","bb1":8.7, "tb1":74.5,"lk1":45.6,"bb2":9.3, "tb2":77.0,"lk2":46.1,"bb3":9.8, "tb3":79.5,"lk3":46.5}'::jsonb,
    '{"b":10,"p":2,"k":4,"d1":"2024-03-01","bb1":6.8, "tb1":65.0,"lk1":43.9,"bb2":7.4, "tb2":68.5,"lk2":44.5,"bb3":7.9, "tb3":71.0,"lk3":45.0}'::jsonb,
    '{"b":11,"p":1,"k":2,"d1":"2024-01-15","bb1":8.5, "tb1":76.0,"lk1":47.5,"bb2":8.9, "tb2":78.5,"lk2":47.9,"bb3":9.2, "tb3":80.0,"lk3":48.2}'::jsonb,
    '{"b":12,"p":2,"k":5,"d1":"2024-03-10","bb1":5.8, "tb1":60.0,"lk1":43.0,"bb2":6.3, "tb2":63.5,"lk2":43.6,"bb3":6.8, "tb3":66.0,"lk3":44.1}'::jsonb,
    '{"b":14,"p":2,"k":3,"d1":"2024-02-15","bb1":8.0, "tb1":72.0,"lk1":45.2,"bb2":8.6, "tb2":75.0,"lk2":45.7,"bb3":9.1, "tb3":77.5,"lk3":46.1}'::jsonb,
    '{"b":15,"p":1,"k":2,"d1":"2024-01-25","bb1":9.0, "tb1":79.0,"lk1":46.3,"bb2":9.6, "tb2":82.0,"lk2":46.8,"bb3":10.2,"tb3":84.5,"lk3":47.2}'::jsonb
  ];
  v_row JSONB;
  v_kid  INTEGER;
  v_d1 DATE; v_d2 DATE; v_d3 DATE;
  v_kunjungan_id INTEGER;
BEGIN
  FOREACH v_row IN ARRAY v_data LOOP
    v_kid := (v_row->>'b')::INTEGER;
    v_d1  := (v_row->>'d1')::DATE;
    v_d2  := v_d1 + INTERVAL '3 months';
    v_d3  := v_d1 + INTERVAL '6 months';

    -- Visit 1
    INSERT INTO kunjungan (id_balita, id_kader, id_posyandu, tanggal_kunjungan, jenis_kunjungan, waktu_mulai, waktu_selesai, status_kesehatan)
    VALUES (v_kid, (v_row->>'k')::INT, (v_row->>'p')::INT, v_d1, 'Rutin', '08:00', '08:20', 'Baik')
    RETURNING id_kunjungan INTO v_kunjungan_id;
    INSERT INTO pengukuran (id_kunjungan, berat_badan, tinggi_badan, lingkar_kepala, usia_bulan, tanggal_ukur)
    VALUES (v_kunjungan_id, (v_row->>'bb1')::NUMERIC, (v_row->>'tb1')::NUMERIC, (v_row->>'lk1')::NUMERIC, 0, v_d1);

    -- Visit 2
    INSERT INTO kunjungan (id_balita, id_kader, id_posyandu, tanggal_kunjungan, jenis_kunjungan, waktu_mulai, waktu_selesai, status_kesehatan)
    VALUES (v_kid, (v_row->>'k')::INT, (v_row->>'p')::INT, v_d2, 'Rutin', '08:00', '08:20', 'Baik')
    RETURNING id_kunjungan INTO v_kunjungan_id;
    INSERT INTO pengukuran (id_kunjungan, berat_badan, tinggi_badan, lingkar_kepala, usia_bulan, tanggal_ukur)
    VALUES (v_kunjungan_id, (v_row->>'bb2')::NUMERIC, (v_row->>'tb2')::NUMERIC, (v_row->>'lk2')::NUMERIC, 0, v_d2);

    -- Visit 3
    INSERT INTO kunjungan (id_balita, id_kader, id_posyandu, tanggal_kunjungan, jenis_kunjungan, waktu_mulai, waktu_selesai, status_kesehatan)
    VALUES (v_kid, (v_row->>'k')::INT, (v_row->>'p')::INT, v_d3, 'Rutin', '08:00', '08:20', 'Baik')
    RETURNING id_kunjungan INTO v_kunjungan_id;
    INSERT INTO pengukuran (id_kunjungan, berat_badan, tinggi_badan, lingkar_kepala, usia_bulan, tanggal_ukur)
    VALUES (v_kunjungan_id, (v_row->>'bb3')::NUMERIC, (v_row->>'tb3')::NUMERIC, (v_row->>'lk3')::NUMERIC, 0, v_d3);
  END LOOP;
END $$;

-- ── Catatan Kader ────────────────────────────────────────────
-- Attached to first visit of at-risk children (12, 6) and one normal child (1)
INSERT INTO catatan_kader (id_kunjungan, observasi_kader, keluhan_ortu, tindakan, rekomendasi, tanggal_followup)
SELECT k.id_kunjungan,
  'Berat badan di bawah rata-rata untuk usia. Terlihat kurang aktif.',
  'Anak susah makan, sering rewel.',
  'Diberikan penyuluhan gizi seimbang kepada orangtua.',
  'Rujuk ke Puskesmas jika berat badan tidak naik bulan depan. Pantau asupan makan harian.',
  k.tanggal_kunjungan + INTERVAL '1 month'
FROM kunjungan k WHERE k.id_balita = 12 ORDER BY k.tanggal_kunjungan ASC LIMIT 1;

INSERT INTO catatan_kader (id_kunjungan, observasi_kader, keluhan_ortu, tindakan, rekomendasi, tanggal_followup)
SELECT k.id_kunjungan,
  'Pertumbuhan tinggi badan lambat dibanding standar WHO.',
  'Ibu merasa anak jarang mau minum susu.',
  'Edukasi ASI dan MPASI. Pemberian suplemen zinc.',
  'Kontrol kembali bulan depan, timbang ulang.',
  k.tanggal_kunjungan + INTERVAL '1 month'
FROM kunjungan k WHERE k.id_balita = 6 ORDER BY k.tanggal_kunjungan ASC LIMIT 1;

INSERT INTO catatan_kader (id_kunjungan, observasi_kader, keluhan_ortu, tindakan, rekomendasi, tanggal_followup)
SELECT k.id_kunjungan,
  'Perkembangan baik, berat badan sesuai standar.',
  'Tidak ada keluhan.',
  'Penimbangan dan pencatatan rutin.',
  'Lanjutkan pola makan saat ini.',
  NULL
FROM kunjungan k WHERE k.id_balita = 1 ORDER BY k.tanggal_kunjungan ASC LIMIT 1;

-- Catatan on pengukuran for the most at-risk child
UPDATE pengukuran
SET catatan = 'Perlu pemantauan intensif. BB tidak sesuai standar WHO untuk usia.'
WHERE id_kunjungan = (
  SELECT k.id_kunjungan FROM kunjungan k
  WHERE k.id_balita = 12
  ORDER BY k.tanggal_kunjungan ASC LIMIT 1
);

-- ── Balita Imunisasi ─────────────────────────────────────────
-- Hepatitis B dose 1 at birth (all active children)
INSERT INTO balita_imunisasi (id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian, petugas_pemberian)
SELECT id_balita, 1, 1, tanggal_lahir, 'Diberikan', 'RS Bersalin', 'Bidan Jaga' FROM balita;

-- BCG at ~1 month
INSERT INTO balita_imunisasi (id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian, petugas_pemberian)
SELECT id_balita, 2, 1, tanggal_lahir + INTERVAL '1 month', 'Diberikan', 'Puskesmas', 'Bidan Puskesmas' FROM balita;

-- Polio dose 1 at ~2 months
INSERT INTO balita_imunisasi (id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian, petugas_pemberian)
SELECT id_balita, 3, 1, tanggal_lahir + INTERVAL '2 months', 'Diberikan', 'Posyandu', 'Kader' FROM balita;

-- DPT-HB-Hib dose 1 at ~2 months
INSERT INTO balita_imunisasi (id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian, petugas_pemberian)
SELECT id_balita, 4, 1, tanggal_lahir + INTERVAL '2 months', 'Diberikan', 'Posyandu', 'Kader' FROM balita;

-- DPT-HB-Hib dose 2 at ~3 months
INSERT INTO balita_imunisasi (id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian, petugas_pemberian)
SELECT id_balita, 4, 2, tanggal_lahir + INTERVAL '3 months', 'Diberikan', 'Posyandu', 'Kader' FROM balita;

-- Campak-Rubella dose 1 at 9 months
INSERT INTO balita_imunisasi (id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian, petugas_pemberian)
SELECT id_balita, 5, 1, tanggal_lahir + INTERVAL '9 months', 'Diberikan', 'Posyandu', 'Kader' FROM balita;

-- Campak-Rubella dose 2 (booster) at 18 months
INSERT INTO balita_imunisasi (id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, lokasi_pemberian, petugas_pemberian)
SELECT id_balita, 5, 2, tanggal_lahir + INTERVAL '18 months', 'Diberikan', 'Posyandu', 'Kader' FROM balita;

-- One pending immunization for child 12 (at-risk) to show incomplete records
INSERT INTO balita_imunisasi (id_balita, id_imunisasi, dosis_ke, tanggal_pemberian, status_pemberian, keterangan)
VALUES (12, 4, 3, '2023-12-15', 'Tertunda', 'Anak sakit saat jadwal, belum di-reschedule');


-- ============================================================
-- SECTION 8: VERIFICATION QUERIES
-- Run these after the script completes to confirm correctness.
-- ============================================================

-- Row counts per table
SELECT 'orangtua'           AS tabel, COUNT(*) AS jumlah FROM orangtua
UNION ALL SELECT 'balita',            COUNT(*) FROM balita
UNION ALL SELECT 'kader',             COUNT(*) FROM kader
UNION ALL SELECT 'posyandu',          COUNT(*) FROM posyandu
UNION ALL SELECT 'imunisasi',         COUNT(*) FROM imunisasi
UNION ALL SELECT 'kunjungan',         COUNT(*) FROM kunjungan
UNION ALL SELECT 'pengukuran',        COUNT(*) FROM pengukuran
UNION ALL SELECT 'catatan_kader',     COUNT(*) FROM catatan_kader
UNION ALL SELECT 'balita_imunisasi',  COUNT(*) FROM balita_imunisasi
UNION ALL SELECT 'standar_pertumbuhan', COUNT(*) FROM standar_pertumbuhan
ORDER BY tabel;

-- Expected counts:
--   orangtua           : 15
--   balita             : 15
--   kader              :  5
--   posyandu           :  2
--   imunisasi          :  8
--   kunjungan          : 42  (14 active children × 3 visits)
--   pengukuran         : 42  (one per kunjungan, z-scores auto-filled)
--   catatan_kader      :  3
--   balita_imunisasi   : 106 (15 children × 7 doses - 1 inactive child skipped for later doses + 1 pending)
--   standar_pertumbuhan: 488

-- Confirm z-scores were auto-calculated by trigger
SELECT
  b.nama,
  k.tanggal_kunjungan,
  p.usia_bulan,
  p.berat_badan,
  p.tinggi_badan,
  p.z_score_bb_u,
  p.z_score_tb_u,
  p.z_score_bb_tb,
  p.status_gizi,
  p.flag_risiko_stunting,
  p.tingkat_risiko
FROM pengukuran p
JOIN kunjungan k ON k.id_kunjungan = p.id_kunjungan
JOIN balita b    ON b.id_balita    = k.id_balita
ORDER BY b.id_balita, k.tanggal_kunjungan;

-- Confirm stunting view returns flagged children
SELECT * FROM v_stunting_risk;