-- ============================================================
-- MIGRASI: Rekening Bank Yayasan & Tanggal Lunas Invoice
-- Jalankan di Supabase SQL Editor SETELAH schema.sql dan schema_roles.sql
-- ============================================================

-- ------------------------------------------------------------
-- 1. TABEL REKENING BANK YAYASAN
-- ------------------------------------------------------------
create table if not exists public.bank_accounts (
  id           uuid primary key default gen_random_uuid(),
  bank_name    text not null,        -- e.g. "BRI", "BNI", "Mandiri"
  account_no   text not null,        -- nomor rekening
  account_name text not null,        -- nama pemilik rekening
  notes        text,                 -- keterangan tambahan (opsional)
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

drop trigger if exists trg_bank_accounts_updated_at on public.bank_accounts;
create trigger trg_bank_accounts_updated_at
  before update on public.bank_accounts
  for each row execute procedure public.set_updated_at();

alter table public.bank_accounts enable row level security;
drop policy if exists "dev_all_bank_accounts" on public.bank_accounts;
create policy "dev_all_bank_accounts"
  on public.bank_accounts for all to anon, authenticated
  using (true) with check (true);

grant select, insert, update, delete on public.bank_accounts to anon, authenticated;

-- ------------------------------------------------------------
-- 2. KOLOM TANGGAL LUNAS DI TABEL INVOICES
-- ------------------------------------------------------------
alter table public.invoices
  add column if not exists paid_off_at timestamptz;

-- ------------------------------------------------------------
-- 3. TRIGGER: Isi paid_off_at otomatis saat invoice lunas
-- ------------------------------------------------------------
create or replace function public.set_invoice_paid_off_at()
returns trigger as $$
begin
  -- Saat status berubah MENJADI 'paid' → isi timestamp lunas
  if new.status = 'paid' and old.status <> 'paid' then
    new.paid_off_at = now();
  end if;
  -- Jika status berubah DARI 'paid' (misal dikoreksi) → hapus timestamp
  if new.status <> 'paid' and old.status = 'paid' then
    new.paid_off_at = null;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_invoice_paid_off_at on public.invoices;
create trigger trg_invoice_paid_off_at
  before update on public.invoices
  for each row execute procedure public.set_invoice_paid_off_at();
