import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

// Base64url encode (JWT standard — URL-safe, no padding)
function base64url(data: string | ArrayBuffer): string {
  let str: string;
  if (typeof data === "string") {
    str = btoa(unescape(encodeURIComponent(data)));
  } else {
    str = btoa(String.fromCharCode(...new Uint8Array(data)));
  }
  return str.replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

// Sign a JWT with the service account private key and exchange it for an
// OAuth2 access token scoped to Firebase Cloud Messaging.
async function getAccessToken(
  serviceAccount: Record<string, string>,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64url(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );

  const signingInput = `${header}.${payload}`;

  // Strip PEM armour and decode PKCS#8 private key
  const pemBody = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\n/g, "");
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${base64url(signature)}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  const { access_token } = await tokenRes.json();
  if (!access_token) throw new Error("Failed to obtain FCM access token");
  return access_token;
}

serve(async (req) => {
  try {
    const body = await req.json();
    const record = body.record ?? {};

    // Ignore if this is not a breaking news article
    if (!record.is_breaking) {
      return new Response("Not a breaking news record — skipping", {
        status: 200,
      });
    }

    // Skip if is_breaking was already true before this update
    // (prevents duplicate notifications on unrelated column updates)
    if (body.old_record?.is_breaking === true) {
      return new Response("Already sent — skipping duplicate", { status: 200 });
    }

    const serviceAccount = JSON.parse(
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!,
    );
    const projectId: string = serviceAccount.project_id;

    const accessToken = await getAccessToken(serviceAccount);

    const title: string = record.content_title ?? "Breaking News";
    const bodyText: string =
      record.content_description ?? "Tap to read the latest.";
    const articleId: string = String(record.id ?? "");

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            topic: "breaking_news",
            notification: {
              title: title,
            },
            // article_id used by the Flutter app to open the correct article on tap
            data: {
              article_id: articleId,
              type: "breaking_news",
            },
            android: {
              notification: {
                channel_id: "breaking_news",
                icon: "ic_notification",
              },
            },
            apns: {
              payload: {
                aps: { "content-available": 1 },
              },
            },
          },
        }),
      },
    );

    const fcmData = await fcmRes.json();

    if (!fcmRes.ok) {
      console.error("FCM error:", JSON.stringify(fcmData));
      return new Response(`FCM error: ${JSON.stringify(fcmData)}`, {
        status: 500,
      });
    }

    console.log("Breaking news notification sent:", JSON.stringify(fcmData));
    return new Response("Notification sent", { status: 200 });
  } catch (err) {
    console.error("send-breaking-news error:", err);
    return new Response(`Error: ${err}`, { status: 500 });
  }
});
