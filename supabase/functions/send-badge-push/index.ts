// Supabase Edge Function: send an APNs alert push to all of a user's devices.
// Invoked by the DB (pg_net) with { user_id, title, body }.
//
// Required env (set via `supabase secrets set ...`):
//   APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID  (com.federi.Next-Wave)
//   APNS_PRIVATE_KEY   -> contents of the AuthKey_XXXX.p8 (PEM, with header/footer)
//   APNS_HOST          -> optional; default https://api.sandbox.push.apple.com
//                          (use https://api.push.apple.com for production/TestFlight)
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (provided automatically)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function b64url(bytes: Uint8Array): string {
  let s = btoa(String.fromCharCode(...bytes));
  return s.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function b64urlStr(str: string): string {
  return b64url(new TextEncoder().encode(str));
}

async function importP8(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"],
  );
}

async function makeJWT(keyId: string, teamId: string, key: CryptoKey): Promise<string> {
  const header = b64urlStr(JSON.stringify({ alg: "ES256", kid: keyId }));
  const payload = b64urlStr(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }));
  const input = `${header}.${payload}`;
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input),
  );
  return `${input}.${b64url(new Uint8Array(sig))}`;
}

Deno.serve(async (req) => {
  try {
    const { user_id, title, body } = await req.json();
    if (!user_id || !title || !body) {
      return new Response("missing fields", { status: 400 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );
    const { data: tokens } = await supabase
      .from("device_tokens").select("token").eq("user_id", user_id);
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
    }

    const keyId = Deno.env.get("APNS_KEY_ID")!;
    const teamId = Deno.env.get("APNS_TEAM_ID")!;
    const bundle = Deno.env.get("APNS_BUNDLE_ID")!;
    const host = Deno.env.get("APNS_HOST") ?? "https://api.sandbox.push.apple.com";
    const key = await importP8(Deno.env.get("APNS_PRIVATE_KEY")!);
    const jwt = await makeJWT(keyId, teamId, key);

    const payload = JSON.stringify({
      aps: { alert: { title, body }, sound: "default" },
      deepLink: "badges",
    });

    let sent = 0;
    for (const { token } of tokens) {
      const res = await fetch(`${host}/3/device/${token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": bundle,
          "apns-push-type": "alert",
        },
        body: payload,
      });
      if (res.status === 200) sent++;
      // Token no longer valid → clean it up.
      if (res.status === 410) {
        await supabase.from("device_tokens").delete().eq("token", token);
      }
    }
    return new Response(JSON.stringify({ sent }), {
      status: 200, headers: { "content-type": "application/json" },
    });
  } catch (e) {
    return new Response(`error: ${e}`, { status: 500 });
  }
});
