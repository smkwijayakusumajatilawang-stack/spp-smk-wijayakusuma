import type { APIRoute } from "astro";
import { createClient } from "@supabase/supabase-js";

export const prerender = false;

// Midtrans bank code mapping
const MIDTRANS_BANK: Record<string, string> = {
  BNI: "bni",
  BRI: "bri",
  PERMATA: "permata",
  BCA: "bca",
};

export const POST: APIRoute = async ({ request }) => {
  // ── 1. Auth check ──────────────────────────────────────────────────────
  const token = (request.headers.get("Authorization") ?? "").replace("Bearer ", "").trim();
  if (!token) {
    return new Response(JSON.stringify({ error: "Unauthorized." }), { status: 401 });
  }

  const supabase = createClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
  );

  const { data: { user }, error: authErr } = await supabase.auth.getUser(token);
  if (authErr || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized." }), { status: 401 });
  }

  // ── 2. Parse body ──────────────────────────────────────────────────────
  let body: {
    student_id?: string;
    invoice_ids?: string[];
    bank_code?: string;
    amount?: number;
    student_name?: string;
  };
  try {
    body = await request.json();
  } catch {
    return new Response(JSON.stringify({ error: "Body tidak valid." }), { status: 400 });
  }

  const { student_id, invoice_ids, bank_code, amount, student_name } = body;
  if (!student_id || !bank_code || !amount || !invoice_ids?.length) {
    return new Response(
      JSON.stringify({ error: "student_id, invoice_ids, bank_code, dan amount wajib diisi." }),
      { status: 400 },
    );
  }

  const validBanks = ["BNI", "BRI", "MANDIRI", "PERMATA", "BCA"];
  if (!validBanks.includes(bank_code)) {
    return new Response(JSON.stringify({ error: `Bank tidak valid. Pilih: ${validBanks.join(", ")}` }), { status: 400 });
  }

  // ── 3. Generate VA via Midtrans atau mode DEV ──────────────────────────
  const midtransKey = import.meta.env.MIDTRANS_SERVER_KEY;
  const isSandbox = import.meta.env.MIDTRANS_ENV !== "production";
  const orderId = `SPP-VA-${Date.now()}-${Math.random().toString(36).slice(2, 7).toUpperCase()}`;
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 jam

  let vaNumber: string | null = null;
  let billKey: string | null = null;
  let billerCode: string | null = null;
  let gatewayResponse: object | null = null;

  if (midtransKey) {
    // ── Mode Midtrans (live/sandbox) ──────────────────────────────────
    const baseUrl = isSandbox
      ? "https://api.sandbox.midtrans.com/v2"
      : "https://api.midtrans.com/v2";

    const authHeader = "Basic " + Buffer.from(midtransKey + ":").toString("base64");

    let chargeBody: object;

    if (bank_code === "MANDIRI") {
      // Mandiri menggunakan echannel
      chargeBody = {
        payment_type: "echannel",
        transaction_details: {
          order_id: orderId,
          gross_amount: Math.round(amount),
        },
        echannel: {
          bill_info1: "Pembayaran SPP:",
          bill_info2: student_name ?? "Siswa",
        },
        custom_expiry: { expiry_duration: 24, unit: "hour" },
      };
    } else {
      chargeBody = {
        payment_type: "bank_transfer",
        transaction_details: {
          order_id: orderId,
          gross_amount: Math.round(amount),
        },
        bank_transfer: {
          bank: MIDTRANS_BANK[bank_code] ?? bank_code.toLowerCase(),
        },
        customer_details: {
          first_name: student_name ?? "Siswa",
        },
        custom_expiry: { expiry_duration: 24, unit: "hour" },
      };
    }

    const mtRes = await fetch(`${baseUrl}/charge`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": authHeader,
      },
      body: JSON.stringify(chargeBody),
    });

    const mtData = await mtRes.json();
    gatewayResponse = mtData;

    if (!mtRes.ok || (mtData.status_code !== "201" && mtData.status_code !== "200")) {
      return new Response(
        JSON.stringify({ error: mtData.status_message ?? "Gagal menghubungi Midtrans." }),
        { status: 502 },
      );
    }

    if (bank_code === "MANDIRI") {
      billerCode = mtData.biller_code ?? null;
      billKey = mtData.bill_key ?? null;
    } else if (bank_code === "PERMATA") {
      vaNumber = mtData.permata_va_number ?? null;
    } else {
      vaNumber = mtData.va_numbers?.[0]?.va_number ?? null;
    }

    // Gunakan expiry dari Midtrans jika ada
    if (mtData.expiry_time) {
      expiresAt.setTime(new Date(mtData.expiry_time).getTime());
    }
  } else {
    // ── Mode DEV: generate VA dummy ────────────────────────────────────
    const prefix: Record<string, string> = {
      BNI: "8808",
      BRI: "8806",
      PERMATA: "8",
      BCA: "70012",
      MANDIRI: "",
    };
    if (bank_code === "MANDIRI") {
      billerCode = "70012";
      billKey = String(Math.floor(Math.random() * 9000000000000) + 1000000000000);
    } else {
      vaNumber = (prefix[bank_code] ?? "8888") + String(Math.floor(Math.random() * 1000000000000)).padStart(12, "0");
    }
    gatewayResponse = { mode: "development", note: "VA dummy — set MIDTRANS_SERVER_KEY untuk mode live" };
  }

  // ── 4. Simpan ke database ──────────────────────────────────────────────
  const serviceKey = import.meta.env.SUPABASE_SERVICE_ROLE_KEY || import.meta.env.PUBLIC_SUPABASE_ANON_KEY;
  const dbClient = createClient(import.meta.env.PUBLIC_SUPABASE_URL, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: vaRecord, error: insertErr } = await dbClient
    .from("virtual_accounts")
    .insert({
      student_id,
      bank_code,
      va_number: vaNumber,
      bill_key: billKey,
      biller_code: billerCode,
      amount: Math.round(amount),
      description: `SPP ${student_name ?? ""}`.trim(),
      status: "pending",
      external_id: orderId,
      expires_at: expiresAt.toISOString(),
      gateway_response: gatewayResponse,
    })
    .select("id")
    .single();

  if (insertErr) {
    return new Response(JSON.stringify({ error: "Gagal menyimpan VA: " + insertErr.message }), { status: 500 });
  }

  // Simpan VA-Invoice lines
  if (invoice_ids.length) {
    await dbClient.from("va_invoice_lines").insert(
      invoice_ids.map((invId) => ({ va_id: vaRecord.id, invoice_id: invId, amount })),
    );
  }

  return new Response(
    JSON.stringify({
      va_id: vaRecord.id,
      bank_code,
      va_number: vaNumber,
      bill_key: billKey,
      biller_code: billerCode,
      amount: Math.round(amount),
      external_id: orderId,
      expires_at: expiresAt.toISOString(),
    }),
    { status: 201, headers: { "Content-Type": "application/json" } },
  );
};
