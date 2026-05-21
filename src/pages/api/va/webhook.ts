import type { APIRoute } from "astro";
import { createClient } from "@supabase/supabase-js";
import { createHash } from "crypto";

export const prerender = false;

/**
 * Midtrans Notification Webhook
 * Konfigurasi URL ini di Midtrans Dashboard → Settings → Configuration
 * URL: https://your-domain.com/api/va/webhook
 */
export const POST: APIRoute = async ({ request }) => {
  let body: Record<string, string>;
  try {
    body = await request.json();
  } catch {
    return new Response("Bad Request", { status: 400 });
  }

  const {
    order_id,
    status_code,
    gross_amount,
    signature_key,
    transaction_status,
    fraud_status,
    payment_type,
  } = body;

  // ── 1. Verifikasi signature Midtrans ───────────────────────────────────
  const serverKey = import.meta.env.MIDTRANS_SERVER_KEY;
  if (serverKey) {
    const expected = createHash("sha512")
      .update(`${order_id}${status_code}${gross_amount}${serverKey}`)
      .digest("hex");
    if (expected !== signature_key) {
      return new Response("Invalid signature", { status: 403 });
    }
  }

  // ── 2. Cari VA record berdasarkan order_id ─────────────────────────────
  const serviceKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY || import.meta.env.PUBLIC_SUPABASE_ANON_KEY;
  const supabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    serviceKey,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  const { data: vaRecord, error: findErr } = await supabase
    .from("virtual_accounts")
    .select("id,student_id,amount,status")
    .eq("external_id", order_id)
    .single();

  if (findErr || !vaRecord) {
    console.error("VA not found for order_id:", order_id);
    return new Response("VA not found", { status: 404 });
  }

  // Sudah diproses sebelumnya? Abaikan duplikat
  if (vaRecord.status === "paid") {
    return new Response(JSON.stringify({ message: "already processed" }), { status: 200 });
  }

  // ── 3. Tentukan status baru berdasarkan notifikasi Midtrans ────────────
  const isPaid =
    (transaction_status === "settlement" || transaction_status === "capture") &&
    (fraud_status === "accept" || fraud_status === undefined || payment_type === "bank_transfer");

  const isExpired = transaction_status === "expire";
  const isCancelled = transaction_status === "cancel" || transaction_status === "deny";

  let newStatus: string | null = null;
  if (isPaid) newStatus = "paid";
  else if (isExpired) newStatus = "expired";
  else if (isCancelled) newStatus = "cancelled";

  if (!newStatus) {
    // Status lain (pending, authorize) — tidak perlu update
    return new Response(JSON.stringify({ message: "no action needed", transaction_status }), { status: 200 });
  }

  // ── 4. Update status VA ────────────────────────────────────────────────
  const updatePayload: Record<string, unknown> = {
    status: newStatus,
    gateway_response: body,
  };
  if (newStatus === "paid") {
    updatePayload.paid_at = new Date().toISOString();
  }

  const { error: updateErr } = await supabase
    .from("virtual_accounts")
    .update(updatePayload)
    .eq("id", vaRecord.id);

  if (updateErr) {
    console.error("Failed to update VA:", updateErr);
    return new Response("DB error", { status: 500 });
  }

  // ── 5. Jika lunas, buat payment record & update invoices ───────────────
  if (newStatus === "paid") {
    // Ambil invoice lines untuk VA ini
    const { data: vaLines } = await supabase
      .from("va_invoice_lines")
      .select("invoice_id,amount")
      .eq("va_id", vaRecord.id);

    if (vaLines?.length) {
      // Buat payment header
      const { data: payment, error: payErr } = await supabase
        .from("payments")
        .insert({
          student_id: vaRecord.student_id,
          payment_date: new Date().toISOString().slice(0, 10),
          state: "paid",
          amount_total: vaRecord.amount,
          amount_paid: vaRecord.amount,
          amount_due: 0,
        })
        .select("id")
        .single();

      if (!payErr && payment) {
        // Update VA dengan payment_id
        await supabase
          .from("virtual_accounts")
          .update({ payment_id: payment.id })
          .eq("id", vaRecord.id);

        // Buat payment_lines & update invoice
        for (const line of vaLines) {
          const { data: inv } = await supabase
            .from("invoices")
            .select("total_amount,paid_amount")
            .eq("id", line.invoice_id)
            .single();

          if (inv) {
            const paidAmount = Number(line.amount || 0);
            const newPaid = Math.min(
              Number(inv.total_amount),
              Number(inv.paid_amount || 0) + paidAmount,
            );
            const newStatus = newPaid >= Number(inv.total_amount) ? "paid" : "posted";

            await supabase.from("payment_lines").insert({
              payment_id: payment.id,
              invoice_id: line.invoice_id,
              amount_total: Number(inv.total_amount) - Number(inv.paid_amount || 0),
              amount_paid: paidAmount,
              amount_residual: Math.max(0, Number(inv.total_amount) - newPaid),
            });

            await supabase
              .from("invoices")
              .update({ paid_amount: newPaid, status: newStatus })
              .eq("id", line.invoice_id);
          }
        }

        // Log audit
        await supabase.from("audit_logs").insert({
          user_email: "system@webhook",
          action: "va_payment_received",
          table_name: "virtual_accounts",
          record_id: vaRecord.id,
          new_data: { order_id, amount: vaRecord.amount },
          notes: `Pembayaran VA via ${payment_type ?? "bank_transfer"} diterima`,
        });
      }
    }
  }

  return new Response(JSON.stringify({ message: "ok", status: newStatus }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
};
