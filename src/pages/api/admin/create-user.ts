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
    return new Response(JSON.stringify({ error: "Forbidden. Hanya admin yang dapat membuat pengguna." }), { status: 403 });
  }

  // ── 2. Validasi body ───────────────────────────────────────────────────
  let body: { email?: string; password?: string; full_name?: string; role?: string };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Body tidak valid." }), { status: 400 });
  }

  const { email, password, full_name, role } = body;
  if (!email || !password) {
    return new Response(JSON.stringify({ error: "Email dan password wajib diisi." }), { status: 400 });
  }
  if (password.length < 8) {
    return new Response(JSON.stringify({ error: "Password minimal 8 karakter." }), { status: 400 });
  }
  const validRoles = ["admin", "kasir"];
  const userRole = validRoles.includes(role ?? "") ? role! : "kasir";

  // ── 3. Buat user dengan service role ──────────────────────────────────
  const serviceRoleKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: "SUPABASE_SERVICE_ROLE_KEY belum dikonfigurasi di environment variables." }),
      { status: 500 },
    );
  }

  const adminSupabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    serviceRoleKey,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  const { data: newUserData, error: createErr } = await adminSupabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (createErr) {
    return new Response(JSON.stringify({ error: createErr.message }), { status: 400 });
  }

  // ── 4. Buat profil user ────────────────────────────────────────────────
  const { error: profileErr } = await adminSupabase
    .from("user_profiles")
    .insert({
      user_id: newUserData.user.id,
      email,
      full_name: full_name?.trim() || null,
      role: userRole,
      is_active: true,
    });

  if (profileErr) {
    // Rollback: hapus user yang baru dibuat
    await adminSupabase.auth.admin.deleteUser(newUserData.user.id);
    return new Response(JSON.stringify({ error: "Gagal membuat profil: " + profileErr.message }), { status: 500 });
  }

  // ── 5. Catat audit log ─────────────────────────────────────────────────
  await supabase.from("audit_logs").insert({
    user_email: user.email,
    action: "create_user",
    table_name: "user_profiles",
    record_id: newUserData.user.id,
    new_data: { email, full_name, role: userRole },
    notes: `Pengguna baru dibuat dengan role ${userRole}`,
  });

  return new Response(
    JSON.stringify({ success: true, user_id: newUserData.user.id }),
    { status: 201, headers: { "Content-Type": "application/json" } },
  );
};
