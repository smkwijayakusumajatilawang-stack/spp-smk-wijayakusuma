import { config } from "dotenv";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
config({ path: resolve(__dirname, "..", ".env") });

const BASE = process.env.PUBLIC_SUPABASE_URL;
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const headers = {
  apikey: KEY,
  Authorization: `Bearer ${KEY}`,
  "Content-Type": "application/json",
  Prefer: "return=minimal",
};

async function deleteAll(table) {
  const url = `${BASE}/rest/v1/${table}?id=neq.00000000-0000-0000-0000-000000000000`;
  const res = await fetch(url, { method: "DELETE", headers });
  const body = await res.text();
  if (!res.ok) {
    console.log(`   ${table.padEnd(18)}: ❌ ${res.status} ${body.slice(0, 120)}`);
    return null;
  }
  let n = 0;
  if (body) {
    try {
      const parsed = JSON.parse(body);
      n = Array.isArray(parsed) ? parsed.length : parsed ?? 0;
    } catch {}
  }
  console.log(`   ${table.padEnd(18)}: ${n > 0 ? n + " baris" : "kosong (sudah)"} ✅`);
  return n;
}

async function countAll(table) {
  const url = `${BASE}/rest/v1/${table}?select=count`;
  const res = await fetch(url, { headers: { ...headers, Prefer: "count=exact" } });
  if (!res.ok) return "❌";
  return res.headers.get("content-range")?.split("/")[1] ?? "?";
}

async function main() {
  console.log("▶ Menghapus semua data siswa dan data terkait...\n");

  // Urutan sesuai foreign key
  const tables = ["payment_lines", "payments", "invoices", "student_discounts", "students"];
  for (const t of tables) {
    await deleteAll(t);
    // jeda kecil biar tidak kena rate limit
    await new Promise(r => setTimeout(r, 120));
  }

  // Verifikasi
  console.log("\n▶ Verifikasi sisa data:");
  await new Promise(r => setTimeout(r, 300));
  for (const t of tables) {
    const c = await countAll(t);
    console.log(`   ${t.padEnd(18)}: ${c}`);
  }

  console.log("\n✅ Selesai. Semua data siswa sudah dihapus.");
}

main().catch(console.error);