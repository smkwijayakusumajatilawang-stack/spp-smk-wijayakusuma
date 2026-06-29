import type { APIRoute } from "astro";
import { createClient } from "@supabase/supabase-js";

export const prerender = false;

export const POST: APIRoute = async ({ request }) => {
  // ── 1. Verifikasi caller adalah admin ──────────────────────────────────
  const authHeader = request.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();
  if (!token) {
    return new Response(JSON.stringify({ error: "Token tidak ditemukan." }), { status: 401 });
  }

  const supabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
  );

  const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
  if (authErr || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized." }), { status: 401 });
  }

  const { data: callerProfile } = await supabase
    .from("user_profiles")
    .select("role")
    .eq("user_id", user.id)
    .single();

  if (callerProfile?.role !== "admin") {
    return new Response(JSON.stringify({ error: "Forbidden. Hanya admin yang dapat mengganti password." }), { status: 403 });
  }

  // ── 2. Validasi body ───────────────────────────────────────────────────
  let body: { target_user_id?: string; new_password?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Body tidak valid." }), { status: 400 });
  }

  const { target_user_id, new_password } = body;

  if (!target_user_id) {
    return new Response(JSON.stringify({ error: "Target user wajib dipilih." }), { status: 400 });
  }
  if (!new_password || new_password.length < 8) {
    return new Response(JSON.stringify({ error: "Password baru minimal 8 karakter." }), { status: 400 });
  }

  // ── 3. Cek target user ada di user_profiles ───────────────────────────
  const { data: targetProfile, error: targetErr } = await supabase
    .from("user_profiles")
    .select("user_id, email, full_name")
    .eq("user_id", target_user_id)
    .single();

  if (targetErr || !targetProfile) {
    return new Response(JSON.stringify({ error: "User target tidak ditemukan." }), { status: 404 });
  }

  // ── 4. Update password dengan service role ─────────────────────────────
  const serviceRoleKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: "SUPABASE_SERVICE_ROLE_KEY belum dikonfigurasi." }),
      { status: 500 },
    );
  }

  const adminSupabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    serviceRoleKey,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  const { error: updateErr } = await adminSupabase.auth.admin.updateUserById(
    target_user_id,
    { password: new_password },
  );

  if (updateErr) {
    return new Response(JSON.stringify({ error: "Gagal mengganti password: " + updateErr.message }), { status: 500 });
  }

  // ── 5. Catat audit log ─────────────────────────────────────────────────
  await supabase.from("audit_logs").insert({
    user_email: user.email,
    action: "change_password",
    table_name: "auth.users",
    record_id: target_user_id,
    new_data: { target_email: targetProfile.email },
    notes: `Password pengguna ${targetProfile.full_name || targetProfile.email} berhasil diganti oleh admin`,
  });

  return new Response(
    JSON.stringify({ success: true, message: `Password ${targetProfile.full_name || targetProfile.email} berhasil diganti.` }),
    { status: 200, headers: { "Content-Type": "application/json" } },
  );
};