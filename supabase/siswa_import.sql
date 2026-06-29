-- ============================================================
-- IMPORT DATA SISWA KE TABEL students
-- Jalankan di Supabase Dashboard → SQL Editor
-- ============================================================

-- ============================================================
-- LANGKAH 1: Tambah kolom yang belum ada di tabel students
-- ============================================================
ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS nisn          TEXT,
  ADD COLUMN IF NOT EXISTS tempat_lahir  TEXT,
  ADD COLUMN IF NOT EXISTS tanggal_lahir DATE,
  ADD COLUMN IF NOT EXISTS jenis_kelamin TEXT,
  ADD COLUMN IF NOT EXISTS alamat        TEXT,
  ADD COLUMN IF NOT EXISTS telepon       TEXT,
  ADD COLUMN IF NOT EXISTS angkatan      INTEGER;

-- ============================================================
-- LANGKAH 2: Insert Tahun Ajaran (skip jika sudah ada)
-- Catatan: tidak ada data TA 2023/2024 di dataset ini
-- ============================================================
INSERT INTO public.academic_years (name, is_active) VALUES
  ('TA 2018/2019', false),
  ('TA 2019/2020', false),
  ('TA 2020/2021', false),
  ('TA 2021/2022', false),
  ('TA 2022/2023', false),
  ('TA 2024/2025', false),
  ('TA 2025/2026', true),
  ('TA 2026/2027', false)
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- LANGKAH 3: Insert Data Siswa
--
-- Normalisasi format tahun ajaran:
--   'TA.2024/2025' → 'TA 2024/2025'
--   '2026/2027'    → 'TA 2026/2027'
--   NULL           → tetap NULL (academic_year_id = NULL)
--
-- Catatan data:
--   - Faizal Akbar (NIS 3222103009): tanggal_lahir '2020-07-30'
--     kemungkinan salah input, sesuaikan manual jika perlu
--   - Ihza Amir Dzikrillah Fatah (NIS 3222502007): tanggal_lahir '2021-01-29'
--     kemungkinan salah input, sesuaikan manual jika perlu
--   - Sayyid Ismail Haniya: tahun ajaran NULL → academic_year_id NULL
--
-- Jika NIS sudah ada di tabel, baris dilewati (DO NOTHING)
-- ============================================================
WITH raw (name, nis, nisn, tempat_lahir, tanggal_lahir, jenis_kelamin, alamat, telepon, ta_raw) AS (
  VALUES
    ('M.Deriyansyah',                   '3223009008',  NULL,           'Lebak',          '2005-01-26', 'Laki-laki',  'kp.monggorkandang',                                                                       '089684451898',   'TA.2024/2025'),
    ('Fadli Firmansyah',                '3223009005',  '20607928',     'Tangerang',       '2004-08-12', 'Laki-laki',  'Kp.Uwung Hilir',                                                                          '0895359884115',  'TA.2024/2025'),
    ('Yoga Bayu Aditya',                '3222008010',  '0022073573',   'Magelang',        '2002-05-22', 'Laki-laki',  'Perum Taman Buah Sukamantri Blok AB-4/02',                                                '081388230020',   'TA 2022/2023'),
    ('Muhammad Zaki',                   '3223009010',  NULL,           'Cianjur',         '2005-04-21', 'Laki-laki',  'Jl.Kano xl no 03',                                                                        NULL,             'TA.2024/2025'),
    ('Dede Zakaria Al Anshor',          '3222008003',  NULL,           'Tangerang',       '2003-10-17', 'Laki-laki',  'Pasar Kemis No.31',                                                                       '087875734675',   'TA 2022/2023'),
    ('Luthfiyah Insaani',               '3223008013',  '20363220',     'Jakarta',         '2003-01-16', 'Perempuan',  'Jl.Ancol Selatan',                                                                        '089526448697',   'TA.2024/2025'),
    ('Firdaus Bun Yanun',               '3222008005',  NULL,           'Tangerang',       '1999-09-02', 'Laki-laki',  'Perum Bumi Indah Tahap 3 Blok HF/12 Ds.Sukamantri',                                       '085694975962',   'TA 2022/2023'),
    ('Ahmad Dian Syarifudin',           '3222008002',  NULL,           'Tangerang',       '2004-06-02', 'Laki-laki',  'Kavling Perkebunan Blok C No.271',                                                        '0895412875509',  'TA 2022/2023'),
    ('Liri Ramadhina Fadillah Nasrul',  '3223009007',  NULL,           'Karawang',        '2004-06-11', 'Perempuan',  'Dusun Cariu Barat',                                                                       '083114443141',   'TA.2024/2025'),
    ('Adji Pramudya Kautzar',           '3222008001',  NULL,           'Jakarta',         '2002-01-02', 'Laki-laki',  'Jl. Rawa Bengkel',                                                                        '085776689695',   'TA 2022/2023'),
    ('Fardi Hamdan Kurnia',             '3223009006',  NULL,           'Jakarta',         '1988-10-07', 'Laki-laki',  'Blok RB 4 No.14 Dasana Indah',                                                            '082113438887',   'TA.2024/2025'),
    ('Prabu Bagas Asidiki',             '3223009012',  NULL,           'Tangerang',       '2004-12-01', 'Laki-laki',  'Kebon Nanas',                                                                             '085718615117',   'TA.2024/2025'),
    ('Arya Athafarrel Syah',            '3223009003',  NULL,           'Bandung',         '2004-10-08', 'Laki-laki',  'Ruko Daen Blok BD No.37',                                                                 '089668226889',   'TA.2024/2025'),
    ('Bagus Mardiansyah',               '3223009004',  NULL,           'Tangerang',       '2005-03-30', 'Laki-laki',  'Kp.Gurubug',                                                                              '08568852845',    'TA.2024/2025'),
    ('Fauzan Syahmi',                   '3222008004',  NULL,           'Jakarta',         '2005-11-01', 'Laki-laki',  'KP.Menceng',                                                                              '081382073188',   'TA 2022/2023'),
    ('Muh Bintang Insan Cemerlang',     '3222008006',  NULL,           'Lumajang',        '2002-01-23', 'Laki-laki',  'Perum Dasana Indah Blok SS.3',                                                            '081335446974',   'TA 2022/2023'),
    ('Nadzwa Salsabila Syahli',         '3223009011',  NULL,           'Tangerang',       '2005-01-02', 'Perempuan',  'Jl Layar III No 15',                                                                      '088212293822',   'TA.2024/2025'),
    ('Annisa Yulianti',                 '3223009002',  NULL,           'Tangerang',       '2003-06-11', 'Perempuan',  'Dasana Indah RI No 7',                                                                    '085695880775',   'TA.2024/2025'),
    ('Aldiansyah',                      '3223009001',  NULL,           'Tasikmalaya',     '2004-03-06', 'Laki-laki',  'Kp.Sempur',                                                                               '0895635744885',  'TA.2024/2025'),
    ('Muhammad Rizalpradana Fadoli',    '3223009009',  NULL,           'Jakarta',         '2002-07-05', 'Laki-laki',  'Jl. Mawadah X No 13 Islamic Village',                                                    '082114870063',   'TA.2024/2025'),
    ('Nanda Dwi Qamara Saputra',        '3222008008',  NULL,           'Tangerang',       '2004-03-25', 'Laki-laki',  'Dasana Indah Blok BE 3/3',                                                                '083871847748',   'TA 2022/2023'),
    ('Nur Izmi Maulidina',              '3222008009',  NULL,           'Jakarta',         '2001-06-18', 'Perempuan',  'JL.Nurul Huda 1 No. 63',                                                                  '0895328073722',  'TA 2022/2023'),
    ('Fiqry Ferdinan Nurhidayat',       '3221008004',  NULL,           'Jakarta',         '2003-03-12', 'Laki-laki',  'JL. Merpati I No. 69',                                                                    '085819495384',   'TA 2021/2022'),
    ('Nofi Budi Raharjo',               '3222103014',  NULL,           'Purbalingga',     '1996-11-14', 'Laki-laki',  'Perum Taman Walet Blok SD/27 Pasar Kemis',                                                '082114605594',   'TA 2019/2020'),
    ('Abdullah Azizi Alfarizi',         '3222204008',  NULL,           'Tangerang',       '2000-01-25', 'Laki-laki',  'Kp.Keboncau',                                                                             '085157523776',   'TA 2018/2019'),
    ('Wendy Sutendy',                   '3221008005',  NULL,           'Tangerang',       '1998-05-22', 'Laki-laki',  'KP. Klebet',                                                                              '081286206861',   'TA 2021/2022'),
    ('Fajar Aldiyansyah Sidiq',         '3222103010',  NULL,           'Banjar Negara',   '1999-11-28', 'Laki-laki',  'KP.Cilongok',                                                                             '0895397320823',  'TA 2019/2020'),
    ('Simon Kasih H.',                  '3222204018',  NULL,           'Subang',          '1999-07-26', 'Laki-laki',  'Jl.Karang Raya No.4',                                                                     '081293326311',   'TA 2018/2019'),
    ('Muhamad Farhan Fauzi',            '3222204012',  NULL,           'Tangerang',       '1999-08-03', 'Laki-laki',  'Kp.Gebang',                                                                               '087878362281',   'TA 2018/2019'),
    ('Muhammad Rizky Pratama',          '3222103013',  NULL,           'Gresik',          '1999-06-23', 'Laki-laki',  'Jl.Kahuripan I',                                                                          '0812139983169',  'TA 2019/2020'),
    ('Ahmad Sopian Sauri',              '3222103015',  NULL,           'Tangerang',       '1998-03-16', 'Laki-laki',  'Jl.Jambu Karya',                                                                          '085930336580',   'TA 2019/2020'),
    ('Nur Muhamad Soleh',               '3222204015',  NULL,           'Kl Progo',        '1997-01-09', 'Laki-laki',  'Kp.Klingkit',                                                                             '089608046965',   'TA 2018/2019'),
    ('Faizal Akbar',                    '3222103009',  NULL,           'Cianjur',         '2020-07-30', 'Laki-laki',  'Cikoneng Baru',                                                                           '0878834348',     'TA 2019/2020'), -- PERIKSA: tanggal lahir diduga salah
    ('Sugiono',                         '3222103022',  NULL,           'Malang',          '2001-03-11', 'Laki-laki',  'Jl.Kisaiman 1',                                                                           '081319258366',   'TA 2020/2021'),
    ('Yunita Budi Wardani',             '3222103012',  NULL,           'Adiluwih',        '1991-07-19', 'Perempuan',  'Jl. Alia Islamic School Perum Desana',                                                    '08891252542',    'TA 2019/2020'),
    ('Ridho Anras',                     '322220417',   NULL,           'Jakarta',         '1999-07-06', 'Laki-laki',  'Jl. Sriwijaya Raya IX No.12',                                                             '08987898831',    'TA 2018/2019'),
    ('Muhammad Farhan Mubarok',         '3222204054',  NULL,           'Tangerang',       '2000-04-14', 'Laki-laki',  'KP. Jatake',                                                                              '083874286626',   'TA 2018/2019'),
    ('Fauzan Kafin Faza',               '3222204011',  NULL,           'Bandung',         '1999-10-26', 'Laki-laki',  'Jl. Kakap IV No.11',                                                                      '089668611821',   'TA 2018/2019'),
    ('Muhamad Agis',                    '3222103011',  NULL,           'Bogor',           '1998-03-11', 'Laki-laki',  'Jl. Cilebut Kaum',                                                                        '0895418070501',  'TA 2019/2020'),
    ('Rizki Mubarok',                   '3221008006',  NULL,           NULL,              '2003-07-18', 'Laki-laki',  'KP. Gunung Sari',                                                                         '089652512837',   'TA 2021/2022'),
    ('Muhammad Adnan Basyuni',          '3222204014',  NULL,           'Tangerang',       '2000-05-12', 'Laki-laki',  'JL. Untung Suropati I',                                                                   '085156057969',   'TA 2018/2019'),
    ('Muhammad Sahriyadi Maulana',      '3222204013',  NULL,           'Tangerang',       '1999-01-13', 'Laki-laki',  'KP. Gaga Inpres',                                                                         '085890081582',   'TA 2018/2019'),
    ('Ricky Noviansyah',                '3222103023',  NULL,           'Tangerang',       '2000-11-17', 'Laki-laki',  'KP. Sempur',                                                                              '0895322688397',  'TA 2020/2021'),
    ('Naditya Romadhoni',               '3222103016',  NULL,           'Tangerang',       '2000-12-19', 'Laki-laki',  'KP. Kebon Kelapa',                                                                        '081210611549',   'TA 2020/2021'),
    ('Tumbuh',                          '3220007006',  NULL,           'Jakarta',         '1972-01-23', 'Laki-laki',  'Serdang Asri 2 Blok. B 02/07',                                                            '081310848233',   'TA 2020/2021'),
    ('Agung Ahmad Hidayat',             '3222204010',  NULL,           'Klaten',          '2000-03-21', 'Laki-laki',  'Kp.Jatake',                                                                               NULL,             'TA 2018/2019'),
    ('Dwi Puspita Sari',                '3221903017',  NULL,           'Jakarta',         '1998-12-26', 'Perempuan',  'Cikande Permai T 7/02',                                                                   NULL,             'TA 2018/2019'),
    ('Ricko Alhabsi',                   '3222103017',  NULL,           'Tangerang',       '1988-10-26', 'Laki-laki',  'Dasana Indah Blok SH-9 No. 28',                                                           NULL,             'TA 2020/2021'),
    ('Suhendi',                         '3222103018',  NULL,           'Tangerang',       '2003-07-23', 'Laki-laki',  'Kp.Rancalabuh',                                                                           NULL,             'TA 2020/2021'),
    ('Adrian Hartanto',                 '3222204009',  NULL,           'Lampung Tengah',  '2000-09-03', 'Laki-laki',  NULL,                                                                                       NULL,             'TA 2018/2019'),
    ('Ayu Wandira',                     '3221008001',  NULL,           'Tangerang',       '2002-05-13', 'Perempuan',  'KP. Rangalabuh',                                                                           NULL,             'TA 2021/2022'),
    ('Sabri',                           '3221008003',  NULL,           'Sugai Simbar',    '1995-12-19', NULL,          NULL,                                                                                       NULL,             'TA 2021/2022'),
    ('Rokhman Nurhidayat',              '32217030292', NULL,           'Cilacap',         '1999-09-11', NULL,          'Citra Raya',                                                                              NULL,             'TA 2018/2019'),
    ('Dedi Iswanto',                    '3221603022',  NULL,           'Jakarta',         '1998-06-21', 'Laki-laki',  'Kp.Kalamean Kel.Badak Anom',                                                              '0895334987507',  'TA 2018/2019'),
    ('Eka Lestari',                     '0001120560',  '0001120560',   'Jakarta',         '2000-01-25', 'Perempuan',  'Medang Lestari Blok A1/I.4',                                                              '081218797733',   'TA 2024/2025'),
    ('Alif Fahmi Hidayatullah',         '202110003',   '0042944225',   'Batam',           '2004-09-08', 'Laki-laki',  'KP. Kebon Manggu No.97',                                                                  '085782421460',   'TA 2024/2025'),
    ('Ramadhani Saputra',               '3222401001',  NULL,           'Tangerang',       '2004-10-21', 'Laki-laki',  'Dasana Indah Blok SO 23/19',                                                              '081285997961',   'TA 2024/2025'),
    ('Yayah Paujiah',                   '3222401011',  NULL,           'Tangerang',       '2006-03-06', 'Perempuan',  'Kp.Jambu',                                                                                '085892401837',   'TA 2024/2025'),
    ('Nani Haerani',                    '3222401009',  '3222401009',   'Tangerang',       '2006-05-25', 'Perempuan',  'Kp. Jambu Karya',                                                                         '085717270192',   'TA 2024/2025'),
    ('Yoshi Nathania Maulana',          '3222401007',  NULL,           'Tangerang',       '2006-09-02', 'Perempuan',  'Jl. Putri Sima Raya No. 18',                                                              '088707723473',   'TA 2024/2025'),
    ('Eka Saputra',                     '3222401008',  NULL,           'Tangerang',       '2005-07-11', 'Laki-laki',  'Kp. Cijengir',                                                                            '0895701060973',  'TA 2024/2025'),
    ('Ahmad Rizal Rifai',               '3222401005',  NULL,           'Tangerang',       '2005-09-20', 'Laki-laki',  'Dasana Indah Blok RD 3/14',                                                               '0895414881330',  'TA 2024/2025'),
    ('Alwan Banu Bekti',                '3222401006',  NULL,           'Tangerang',       '2006-04-17', 'Laki-laki',  'Vila Tangerang Elok Blok D 5/9',                                                          '085778813581',   'TA 2024/2025'),
    ('Muhamad Hamdali',                 '3222401010',  NULL,           'Tangerang',       '2006-07-07', 'Laki-laki',  'Kp. Jambu',                                                                               '083815083640',   'TA 2024/2025'),
    ('Hardin Arthand Syach',            '3222401004',  NULL,           'Jakarta',         '2004-08-04', 'Laki-laki',  'Dasana Indah Blok TH 9 No 15',                                                            '081281949409',   'TA 2024/2025'),
    ('Ana Nova Widuri',                 '3222401012',  NULL,           'Tangerang',       '2006-11-02', 'Perempuan',  'Mekar Asri Blok E 07/3A',                                                                 '083138031751',   'TA.2024/2025'),
    ('Wira P. Manik',                   '3222501001',  NULL,           'Medan',           '2002-08-07', 'Laki-laki',  'Jl. Penggilingan Baru',                                                                   '085772480607',   'TA.2025/2026'),
    ('Mochamad Faridz Rizaldi',         '3222501002',  NULL,           'Tangerang',       '2006-06-12', 'Laki-laki',  'Jl.Tongkol Raya No. 139',                                                                 '081389879186',   'TA.2025/2026'),
    ('Andrea Mayqa Zharin',             '3222501003',  NULL,           'Jakarta',         '2007-05-20', 'Perempuan',  'Jl.Perum Dasana Indah Blok TH No.15 Bojong Nangka',                                       '081211770409',   'TA 2025/2026'),
    ('Dimas Agung Saepuloh',            '3222501004',  NULL,           'Jakarta',         '2005-01-16', 'Laki-laki',  'BTN Griya Kondang Lestari Blok A-1 No.4',                                                 '087794746516',   'TA.2025/2026'),
    ('Ahmad Daffa Alfarizi',            '3222501006',  NULL,           'Palembang',       '2007-06-07', 'Laki-laki',  'Jl. KH. Amsir',                                                                           '082114186647',   'TA 2025/2026'),
    ('Ajie Nikmatullah Abdulhalim',     '3222501005',  NULL,           'Tangerang',       '2007-10-23', 'Laki-laki',  'Dasana Indah RK 12/04',                                                                   '0895402618228',  'TA.2025/2026'),
    ('Ihza Amir Dzikrillah Fatah',      '3222502007',  NULL,           'Jakarta',         '2021-01-29', 'Laki-laki',  'Permata Hijau Permai Blok AR 3/15 Kaliabang Tengah Bekasi Utara',                         '085742205574',   '2026/2027'),  -- PERIKSA: tanggal lahir diduga salah
    ('Sayyid Ismail Haniya',            '3222502008',  '0072143234',   'Bekasi',          '2007-06-21', 'Laki-laki',  'Villa Indah Permai Blok i28 No2 RT06 RW36 Kel. Teluk Pucung Kec. Bekasi Utara Kota Bekasi','085161200763',   NULL)          -- tahun ajaran tidak diketahui
),
normalized AS (
  SELECT
    name,
    nis,
    nisn,
    tempat_lahir,
    tanggal_lahir::DATE AS tanggal_lahir,
    jenis_kelamin,
    alamat,
    telepon,
    CASE
      WHEN ta_raw IS NULL             THEN NULL
      WHEN ta_raw LIKE 'TA.%'        THEN 'TA ' || substring(ta_raw FROM 4)
      WHEN ta_raw NOT LIKE 'TA %'    THEN 'TA ' || ta_raw
      ELSE ta_raw
    END AS ta_normalized
  FROM raw
)
INSERT INTO public.students
  (name, nis, nisn, tempat_lahir, tanggal_lahir, jenis_kelamin, alamat, telepon, academic_year_id, angkatan)
SELECT
  n.name,
  n.nis,
  n.nisn,
  n.tempat_lahir,
  n.tanggal_lahir,
  n.jenis_kelamin,
  n.alamat,
  n.telepon,
  ay.id AS academic_year_id,
  NULL::INTEGER AS angkatan
FROM normalized n
LEFT JOIN public.academic_years ay ON ay.name = n.ta_normalized
ON CONFLICT (nis) DO NOTHING;

-- ============================================================
-- Verifikasi hasil import
-- ============================================================
SELECT
  s.name,
  s.nis,
  s.nisn,
  s.tanggal_lahir,
  s.jenis_kelamin,
  ay.name AS tahun_ajaran
FROM public.students s
LEFT JOIN public.academic_years ay ON ay.id = s.academic_year_id
ORDER BY ay.name, s.name;
