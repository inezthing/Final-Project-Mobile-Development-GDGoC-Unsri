// supabase/functions/send-push/index.ts
//
// Edge Function ini DIPANGGIL OTOMATIS oleh Database Webhook Supabase
// setiap kali ada row baru masuk ke tabel `notifications`.
// Tugasnya: cari fcm_token milik user itu di `device_tokens`, terus
// kirim push lewat FCM HTTP v1 API pakai Service Account key.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface WebhookPayload {
  type: 'INSERT';
  table: string;
  record: {
    id: string;
    user_id: string;
    title: string;
    body: string;
    type: string;
    related_order_id: string | null;
  };
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

// Ubah base64 standar jadi base64url (syarat format JWT)
function base64url(input: string): string {
  return input.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// FCM v1 API butuh OAuth2 access token, BUKAN service account key langsung.
// Access token ini didapat dengan bikin & nandatangani JWT pakai private key
// dari service account, lalu ditukar ke Google.
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const enc = (obj: unknown) => base64url(btoa(JSON.stringify(obj)));
  const unsigned = `${enc(header)}.${enc(claim)}`;

  // private_key dari JSON itu formatnya PEM -- perlu di-strip header/footer-nya
  // dan di-decode dari base64 sebelum bisa dipakai Web Crypto API.
  const pemBody = serviceAccount.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binaryKey = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signatureBuf = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const signature = base64url(
    btoa(String.fromCharCode(...new Uint8Array(signatureBuf))),
  );

  const jwt = `${unsigned}.${signature}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const json = await res.json();
  if (!res.ok) {
    throw new Error(`Gagal ambil access token dari Google: ${JSON.stringify(json)}`);
  }
  return json.access_token as string;
}

Deno.serve(async (req: Request) => {
  try {
    const payload: WebhookPayload = await req.json();
    const notif = payload.record;

    // Pakai service role key (bukan anon key) supaya bisa baca device_tokens
    // siapapun -- ini jalan di server, bukan di HP user, jadi aman.
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: tokens, error } = await supabase
      .from('device_tokens')
      .select('fcm_token')
      .eq('user_id', notif.user_id);

    if (error) throw error;

    if (!tokens || tokens.length === 0) {
      // User ini belum pernah login di device manapun (atau belum kasih izin
      // notif) -- bukan error, cuma emang gak ada tempat buat ngirim.
      return new Response(JSON.stringify({ skipped: 'no device token for user' }), {
        status: 200,
      });
    }

    const serviceAccount: ServiceAccount = JSON.parse(
      Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!,
    );
    const accessToken = await getAccessToken(serviceAccount);

    // Kirim ke SEMUA device milik user ini (jaga-jaga dia login di >1 HP)
    const results = [];
    for (const { fcm_token } of tokens) {
      const fcmRes = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: fcm_token,
              notification: {
                title: notif.title,
                body: notif.body,
              },
              // Ini yang dibaca `_handleTap()` di push_notification_service.dart
              // buat nentuin mau navigate ke halaman mana pas notif di-tap.
              data: {
                type: notif.type ?? '',
                related_order_id: notif.related_order_id ?? '',
              },
            },
          }),
        },
      );
      const fcmJson = await fcmRes.json();
      results.push({ token: fcm_token, ok: fcmRes.ok, response: fcmJson });
    }

    return new Response(JSON.stringify({ results }), { status: 200 });
  } catch (e) {
    console.error('send-push error:', e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});