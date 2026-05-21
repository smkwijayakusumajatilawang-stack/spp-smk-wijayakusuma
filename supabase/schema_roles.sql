-- ============================================================
-- SCHEMA TAMBAHAN: Roles, Virtual Accounts, Audit Logs
-- Jalankan di Supabase SQL Editor SETELAH schema.sql
-- ============================================================

-- ------------------------------------------------------------
-- 1. USER PROFILES (manajemen role admin/kasir)
-- ------------------------------------------------------------
create table if not exists public.user_profiles (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null unique,
  email       text not null,
  full_name   text,
  role        text not null default 'kasir' check (role in ('admin', 'kasir')),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 2. AUDIT LOGS (rekam jejak koreksi admin)
-- ------------------------------------------------------------
create table if not exists public.audit_logs (
  id          uuid primary key default gen_random_uuid(),
  user_email  text,
  action      text not null,       -- 'void_payment', 'edit_invoice', 'create_user', dll
  table_name  text not null,
  record_id   uuid,
  old_data    jsonb,
  new_data    jsonb,
  notes       text,
  created_at  timestamptz not null default now()
);

-- ------------------------------------------------------------
-- 3. VIRTUAL ACCOUNTS
-- ------------------------------------------------------------
create table if not exists public.virtual_accounts (
  id               uuid primary key default gen_random_uuid(),
  student_id       uuid not null references public.students(id) on delete restrict,
  bank_code        text not null check (bank_code in ('BNI', 'BRI', 'MANDIRI', 'PERMATA', 'BCA')),
  va_number        text,
  bill_key         text,         -- khusus Mandiri
  biller_code      text,         -- khusus Mandiri
  amount           numeric(14,2) not null,
  description      text,
  status           text not null default 'pending'
                   check (status in ('pending', 'paid', 'expired', 'cancelled')),
  external_id      text unique,  -- order_id di payment gateway
  payment_id       uuid references public.payments(id),
  expires_at       timestamptz,
  paid_at          timestamptz,
  gateway_response jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- VA ↔ Invoice lines (1 VA bisa bayar beberapa invoice)
create table if not exists public.va_invoice_lines (
  id         uuid primary key default gen_random_uuid(),
  va_id      uuid not null references public.virtual_accounts(id) on delete cascade,
  invoice_id uuid not null references public.invoices(id) on delete restrict,
  amount     numeric(14,2) not null default 0,
  unique (va_id, invoice_id)
);

-- ------------------------------------------------------------
-- 4. TAMBAH KOLOM VOID KE PAYMENTS
-- ------------------------------------------------------------
alter table public.payments
  add column if not exists is_voided   boolean     not null default false,
  add column if not exists void_reason text,
  add column if not exists voided_by   text,
  add column if not exists voided_at   timestamptz;

-- ------------------------------------------------------------
-- 5. TRIGGERS updated_at
-- ------------------------------------------------------------
-- Fungsi sudah ada di schema.sql, tinggal pasang trigger baru

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute procedure public.set_updated_at();

drop trigger if exists trg_virtual_accounts_updated_at on public.virtual_accounts;
create trigger trg_virtual_accounts_updated_at
  before update on public.virtual_accounts
  for each row execute procedure public.set_updated_at();

-- ------------------------------------------------------------
-- 6. ROW LEVEL SECURITY
-- ------------------------------------------------------------
alter table public.user_profiles    enable row level security;
alter table public.audit_logs       enable row level security;
alter table public.virtual_accounts enable row level security;
alter table public.va_invoice_lines enable row level security;

drop policy if exists "dev_all_user_profiles"    on public.user_profiles;
drop policy if exists "dev_all_audit_logs"       on public.audit_logs;
drop policy if exists "dev_all_virtual_accounts" on public.virtual_accounts;
drop policy if exists "dev_all_va_invoice_lines" on public.va_invoice_lines;

create policy "dev_all_user_profiles"    on public.user_profiles    for all to anon, authenticated using (true) with check (true);
create policy "dev_all_audit_logs"       on public.audit_logs       for all to anon, authenticated using (true) with check (true);
create policy "dev_all_virtual_accounts" on public.virtual_accounts for all to anon, authenticated using (true) with check (true);
create policy "dev_all_va_invoice_lines" on public.va_invoice_lines for all to anon, authenticated using (true) with check (true);

grant select, insert, update, delete on
  public.user_profiles,
  public.audit_logs,
  public.virtual_accounts,
  public.va_invoice_lines
to anon, authenticated;
