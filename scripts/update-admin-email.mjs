/**
 * Script untuk mengupdate email admin.
 * Jalankan: node scripts/update-admin-email.mjs
 */

import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

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

const OLD_EMAIL = "admin@sekolah.sch.id";
const NEW_EMAIL = "admin@smkwijayakusuma.sch.id";

const adminSupabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

console.log(`\n🔧 Mengupdate email admin: ${OLD_EMAIL} → ${NEW_EMAIL}\n`);

// 1. Cari user berdasarkan email lama
const { data: users } = await adminSupabase.auth.admin.listUsers();
const user = users?.users?.find((u) => u.email === OLD_EMAIL);

if (!user) {
  console.log(`ℹ️  User ${OLD_EMAIL} tidak ditemukan. Mencoba cari ${NEW_EMAIL}...`);
  const newUser = users?.users?.find((u) => u.email === NEW_EMAIL);
  if (newUser) {
    console.log(`✅ User ${NEW_EMAIL} sudah ada (id: ${newUser.id}). Hanya perlu update profil.`);
    // Update profil saja
    const { error: updErr } = await adminSupabase
      .from("user_profiles")
      .update({ email: NEW_EMAIL })
      .eq("user_id", newUser.id)
      .eq("email", OLD_EMAIL);

    if (updErr) {
      console.error("❌ Gagal update profil:", updErr.message);
    } else {
      console.log("✅ Email di profil sudah benar.");
    }
  } else {
    console.error("❌ Tidak ditemukan user admin.");
  }
  process.exit(0);
}

// 2. Update email di auth
const { error: authErr } = await adminSupabase.auth.admin.updateUserById(user.id, {
  email: NEW_EMAIL,
});

if (authErr) {
  console.error("❌ Gagal update email di auth:", authErr.message);
  process.exit(1);
}
console.log(`✅ Email di auth berhasil diupdate.`);

// 3. Update email di user_profiles
const { error: profileErr } = await adminSupabase
  .from("user_profiles")
  .update({ email: NEW_EMAIL })
  .eq("user_id", user.id);

if (profileErr) {
  console.error("❌ Gagal update email di profil:", profileErr.message);
  process.exit(1);
}
console.log(`✅ Email di profil berhasil diupdate.`);

console.log(`
╔══════════════════════════════════════════════╗
║         EMAIL ADMIN BERHASIL DIUBAH         ║
╠══════════════════════════════════════════════╣
║  Email Lama : ${OLD_EMAIL.padEnd(28)} ║
║  Email Baru : ${NEW_EMAIL.padEnd(28)} ║
╚══════════════════════════════════════════════╝
`);