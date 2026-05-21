# SPP App (Astro + Tailwind + Supabase)

Implementasi aplikasi SPP siswa berbasis flow:
- Master data (`siswa`, `komponen biaya`, `periode tagihan`)
- Transaksi (`tagihan siswa`, `pembayaran invoice`)
- Dashboard ringkas (jumlah siswa, total tagihan, outstanding)

## Tech Stack

- Astro
- Tailwind CSS (v4 via Vite plugin)
- Supabase (Postgres + API)

## Struktur Penting

```text
src/
  layouts/AppLayout.astro
  pages/
    index.astro
    master/
      siswa.astro
      komponen.astro
      periode.astro
    tagihan/index.astro
    pembayaran/index.astro
supabase/
  schema.sql
```

## 1) Setup Database Supabase

1. Buka SQL Editor di Supabase.
2. Jalankan file [`supabase/schema.sql`](./supabase/schema.sql).
3. Pastikan semua tabel berhasil dibuat.

Catatan:
- `schema.sql` ini pakai policy `dev_all_anon_*` untuk mempermudah development.
- Untuk production, ganti policy agar lebih aman per role/user.

## 2) Setup Environment

Copy `.env.example` jadi `.env`.

Isi:

```env
PUBLIC_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
PUBLIC_SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## 3) Jalankan Aplikasi

```bash
npm install
npm run dev
```

App jalan di `http://localhost:4321`.

## 4) Alur Pakai Cepat

1. Buka `Master > Periode Tagihan`, tambah tahun ajaran + periode.
2. Buka `Master > Komponen Biaya`, tambah komponen dan nominal default.
3. Buka `Master > Siswa`, tambah siswa + kelas + orang tua.
4. Buka `Tagihan Siswa`, buat invoice per siswa.
5. Buka `Pembayaran`, pilih siswa, centang invoice, proses payment.
6. Cek `Dashboard` untuk ringkasan.

## Validasi Fungsional yang Sudah Dibuat

- Invoice unik per kombinasi `student + component + period`.
- Status pembayaran flow: `draft -> partial -> paid` (dan tabel `payments` juga support `done`).
- Pembayaran akan update `paid_amount` dan `status` di tabel `invoices`.

## Akun Supabase
dpsbantenraya@gmail.com