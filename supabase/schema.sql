create extension if not exists pgcrypto;

-- Drop semua tabel lama (CASCADE menghapus FK & policy secara otomatis)
-- Urutan: tabel paling bergantung dihapus duluan
drop table if exists public.payment_lines    cascade;
drop table if exists public.payments         cascade;
drop table if exists public.invoices         cascade;
drop table if exists public.student_discounts cascade;
drop table if exists public.annual_fees      cascade;
drop table if exists public.students         cascade;
drop table if exists public.guardians        cascade;
drop table if exists public.components       cascade;
drop table if exists public.classes          cascade;
drop table if exists public.billing_periods  cascade;
drop table if exists public.academic_years   cascade;

-- ============================================================
-- TABEL
-- ============================================================

create table public.academic_years (
	id uuid primary key default gen_random_uuid(),
	name text not null unique,
	is_active boolean not null default false,
	created_at timestamptz not null default now()
);

create table public.billing_periods (
	id uuid primary key default gen_random_uuid(),
	academic_year_id uuid not null references public.academic_years(id) on delete cascade,
	name text not null,
	code text not null,
	start_date date not null,
	end_date date not null,
	created_at timestamptz not null default now(),
	unique (academic_year_id, code)
);

create table public.classes (
	id uuid primary key default gen_random_uuid(),
	academic_year_id uuid not null references public.academic_years(id) on delete cascade,
	name text not null,
	jenjang text,
	created_at timestamptz not null default now(),
	unique (academic_year_id, name)
);

create table public.guardians (
	id uuid primary key default gen_random_uuid(),
	name text not null,
	phone text,
	email text,
	created_at timestamptz not null default now()
);

create table public.students (
	id uuid primary key default gen_random_uuid(),
	name text not null,
	nis text unique,
	guardian_id uuid references public.guardians(id) on delete set null,
	class_id uuid references public.classes(id) on delete set null,
	academic_year_id uuid references public.academic_years(id) on delete set null,
	created_at timestamptz not null default now()
);

create table public.components (
	id uuid primary key default gen_random_uuid(),
	name text not null unique,
	payment_type text not null check (payment_type in ('cicil', 'tunai')),
	default_amount numeric(14,2) not null default 0,
	is_active boolean not null default true,
	created_at timestamptz not null default now()
);

create table public.annual_fees (
	id uuid primary key default gen_random_uuid(),
	academic_year_id uuid not null references public.academic_years(id) on delete cascade,
	component_id uuid not null references public.components(id) on delete cascade,
	amount numeric(14,2) not null default 0,
	created_at timestamptz not null default now(),
	unique (academic_year_id, component_id)
);

create table public.student_discounts (
	id uuid primary key default gen_random_uuid(),
	student_id uuid not null references public.students(id) on delete cascade,
	component_id uuid not null references public.components(id) on delete cascade,
	discount_amount numeric(14,2) not null default 0,
	discount_percent numeric(5,2) not null default 0,
	notes text,
	created_at timestamptz not null default now(),
	unique (student_id, component_id)
);

create table public.invoices (
	id uuid primary key default gen_random_uuid(),
	student_id uuid not null references public.students(id) on delete cascade,
	component_id uuid not null references public.components(id) on delete restrict,
	period_id uuid not null references public.billing_periods(id) on delete restrict,
	status text not null default 'draft' check (status in ('draft', 'posted', 'paid', 'cancelled')),
	total_amount numeric(14,2) not null default 0,
	paid_amount numeric(14,2) not null default 0,
	paid_off_at timestamptz,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now(),
	unique (student_id, component_id, period_id)
);

create table public.payments (
	id uuid primary key default gen_random_uuid(),
	payment_no text generated always as ('PAY-' || replace(id::text, '-', '')) stored,
	payment_date date not null default current_date,
	student_id uuid not null references public.students(id) on delete restrict,
	state text not null default 'draft' check (state in ('draft', 'partial', 'paid', 'done')),
	amount_total numeric(14,2) not null default 0,
	amount_paid numeric(14,2) not null default 0,
	amount_due numeric(14,2) not null default 0,
	created_at timestamptz not null default now()
);

create table public.payment_lines (
	id uuid primary key default gen_random_uuid(),
	payment_id uuid not null references public.payments(id) on delete cascade,
	invoice_id uuid not null references public.invoices(id) on delete restrict,
	amount_total numeric(14,2) not null default 0,
	amount_paid numeric(14,2) not null default 0,
	amount_residual numeric(14,2) not null default 0,
	created_at timestamptz not null default now()
);

-- ============================================================
-- FUNCTION & TRIGGER
-- ============================================================

create or replace function public.set_updated_at()
returns trigger as $$
begin
	new.updated_at = now();
	return new;
end;
$$ language plpgsql;

drop trigger if exists trg_invoices_updated_at on public.invoices;
create trigger trg_invoices_updated_at
before update on public.invoices
for each row
execute procedure public.set_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.academic_years    enable row level security;
alter table public.billing_periods   enable row level security;
alter table public.classes           enable row level security;
alter table public.guardians         enable row level security;
alter table public.students          enable row level security;
alter table public.components        enable row level security;
alter table public.annual_fees       enable row level security;
alter table public.student_discounts enable row level security;
alter table public.invoices          enable row level security;
alter table public.payments          enable row level security;
alter table public.payment_lines     enable row level security;

drop policy if exists "dev_all_anon_academic_years"    on public.academic_years;
drop policy if exists "dev_all_anon_billing_periods"   on public.billing_periods;
drop policy if exists "dev_all_anon_classes"           on public.classes;
drop policy if exists "dev_all_anon_guardians"         on public.guardians;
drop policy if exists "dev_all_anon_students"          on public.students;
drop policy if exists "dev_all_anon_components"        on public.components;
drop policy if exists "dev_all_anon_annual_fees"       on public.annual_fees;
drop policy if exists "dev_all_anon_student_discounts" on public.student_discounts;
drop policy if exists "dev_all_anon_invoices"          on public.invoices;
drop policy if exists "dev_all_anon_payments"          on public.payments;
drop policy if exists "dev_all_anon_payment_lines"     on public.payment_lines;

create policy "dev_all_anon_academic_years"    on public.academic_years    for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_billing_periods"   on public.billing_periods   for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_classes"           on public.classes           for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_guardians"         on public.guardians         for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_students"          on public.students          for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_components"        on public.components        for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_annual_fees"       on public.annual_fees       for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_student_discounts" on public.student_discounts for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_invoices"          on public.invoices          for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_payments"          on public.payments          for all to anon, authenticated using (true) with check (true);
create policy "dev_all_anon_payment_lines"     on public.payment_lines     for all to anon, authenticated using (true) with check (true);

-- ============================================================
-- GRANT PERMISSIONS
-- Diperlukan setelah DROP+CREATE karena grant lama ikut terhapus
-- ============================================================

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
