-- ============================================================
-- HAPUS SEMUA DATA SISWA DAN DATA TERKAIT
-- Urutan berdasarkan foreign key dependencies
-- ============================================================

-- 1. Hapus payment_lines (terkait payments & invoices)
delete from public.payment_lines;

-- 2. Hapus payments (FK RESTRICT ke students)
delete from public.payments;

-- 3. Hapus invoices (FK CASCADE ke students, tapi payment_lines sudah kosong)
delete from public.invoices;

-- 4. Hapus student_discounts (FK CASCADE ke students)
delete from public.student_discounts;

-- 5. Hapus semua siswa
delete from public.students;

-- Verifikasi
select 'payment_lines' as tabel, count(*) as sisa from public.payment_lines
union all
select 'payments', count(*) from public.payments
union all
select 'invoices', count(*) from public.invoices
union all
select 'student_discounts', count(*) from public.student_discounts
union all
select 'students', count(*) from public.students;