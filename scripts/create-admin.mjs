/**
 * Script bootstrap: membuat akun admin pertama.
 * Jalankan: node scripts/create-admin.mjs
 *
 * Pastikan SUPABASE_SERVICE_ROLE_KEY sudah diisi di .env
 */

import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

// Load .env secara manual (tanpa dotenv)
const __dirname = dirname(fileURLToPath(import.meta.url));
const envPath = resolve(__dirname, "..", ".env");
const envContent = readFileSync(envPath, "utf-8");
const env = {};
for (const line of envContent.split("\n")) {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith("#")) continue;
  const idx = trimmed.indexOf("=");
  if (idx === -1) continue;
  env[trimmed.slice(0, idx).trim()] = trimmed.slice(idx + 1).trim();
}

const SUPABASE_URL = env.PUBLIC_SUPABASE_URL;
const SERVICE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error("❌ PUBLIC_SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY harus diisi di .env");
  process.exit(1);
}

// ─── Konfigurasi admin yang akan dibuat ────────────────────────────────────
const ADMIN_EMAIL = "admin@smkwijayakusuma.sch.id";
const ADMIN_PASSWORD = "Admin123456";
const ADMIN_NAME = "Administrator";

// ─── Mulai proses ──────────────────────────────────────────────────────────
const adminSupabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

console.log(`\n🔧 Membuat akun admin: ${ADMIN_EMAIL}\n`);

// 1. Cek apakah user sudah ada di auth
const { data: existingUsers } = await adminSupabase.auth.admin.listUsers();
const alreadyExists = existingUsers?.users?.find((u) => u.email === ADMIN_EMAIL);

let userId;

if (alreadyExists) {
  console.log(`ℹ️  User ${ADMIN_EMAIL} sudah ada di auth (id: ${alreadyExists.id}).`);
  userId = alreadyExists.id;
} else {
  // Buat user baru
  const { data: newUser, error: createErr } = await adminSupabase.auth.admin.createUser({
    email: ADMIN_EMAIL,
    password: ADMIN_PASSWORD,
    email_confirm: true,
  });

  if (createErr) {
    console.error("❌ Gagal membuat user:", createErr.message);
    process.exit(1);
  }

  userId = newUser.user.id;
  console.log(`✅ User berhasil dibuat (id: ${userId})`);
}

// 2. Cek apakah profil sudah ada
const { data: existingProfile } = await adminSupabase
  .from("user_profiles")
  .select("id, role")
  .eq("user_id", userId)
  .single();

if (existingProfile) {
  if (existingProfile.role !== "admin") {
    // Update role ke admin
    const { error: updErr } = await adminSupabase
      .from("user_profiles")
      .update({ role: "admin", is_active: true })
      .eq("id", existingProfile.id);

    if (updErr) {
      console.error("❌ Gagal update role:", updErr.message);
      process.exit(1);
    }
    console.log(`✅ Profil diupdate ke role admin.`);
  } else {
    console.log(`ℹ️  Profil admin sudah ada dan aktif.`);
  }
} else {
  // Buat profil baru
  const { error: profileErr } = await adminSupabase
    .from("user_profiles")
    .insert({
      user_id: userId,
      email: ADMIN_EMAIL,
      full_name: ADMIN_NAME,
      role: "admin",
      is_active: true,
    });

  if (profileErr) {
    console.error("❌ Gagal membuat profil:", profileErr.message);
    process.exit(1);
  }
  console.log(`✅ Profil admin berhasil dibuat.`);
}

console.log(`
╔══════════════════════════════════════════════╗
║          AKUN ADMIN SIAP DIGUNAKAN          ║
╠══════════════════════════════════════════════╣
║  Email    : ${ADMIN_EMAIL.padEnd(30)} ║
║  Password : ${ADMIN_PASSWORD.padEnd(30)} ║
║  Role     : admin                           ║
╚══════════════════════════════════════════════╝

🌐 Login di: http://localhost:4321/login
📍 Admin panel: http://localhost:4321/admin

⚠️  Segera ganti password setelah login pertama kali!
`);