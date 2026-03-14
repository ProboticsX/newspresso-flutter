import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const FIREBASE_PROJECT_ID = 'newspresso-3db5c'

Deno.serve(async () => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // Get FCM OAuth2 access token from Firebase service account
  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT')!)
  const accessToken = await getFcmAccessToken(serviceAccount)

  // Fetch all users that have a registered FCM token
  const { data: users, error } = await supabase
    .from('users')
    .select('id, fcm_token, category_preferences')
    .not('fcm_token', 'is', null)

  if (error) {
    console.error('Failed to fetch users:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }

  if (!users?.length) {
    return new Response(JSON.stringify({ message: 'No users with FCM tokens' }), { status: 200 })
  }

  const since24h = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
  const since48h = new Date(Date.now() - 48 * 60 * 60 * 1000).toISOString()
  const staleTokenIds: string[] = []
  let sent = 0
  let skipped = 0
  let failed = 0

  for (const user of users) {
    // Get top 3 categories from behavioral scores; fall back to saved preferences
    const { data: scores } = await supabase
      .from('user_category_scores')
      .select('category')
      .eq('user_id', user.id)
      .order('score', { ascending: false })
      .limit(3)

    const topCategories: string[] = scores?.length
      ? scores.map((s: { category: string }) => s.category)
      : (user.category_preferences ?? []).slice(0, 3)

    if (!topCategories.length) {
      skipped++
      continue
    }

    // Fetch top 3 matching articles from last 24h; extend to 48h if too few
    let { data: articles } = await supabase
      .from('newspresso_aggregated_news_in')
      .select('content_title')
      .overlaps('categories', topCategories)
      .eq('is_ready', true)
      .gte('published_at', since24h)
      .order('published_at', { ascending: false })
      .limit(3)

    if (!articles?.length || articles.length < 2) {
      const { data: fallback } = await supabase
        .from('newspresso_aggregated_news_in')
        .select('content_title')
        .overlaps('categories', topCategories)
        .eq('is_ready', true)
        .gte('published_at', since48h)
        .order('published_at', { ascending: false })
        .limit(3)
      articles = fallback
    }

    if (!articles?.length) {
      skipped++
      continue
    }

    const body = articles
      .map((a: { content_title: string }) => `• ${a.content_title}`)
      .join('\n')

    const result = await sendFcmMessage(user.fcm_token, accessToken, {
      title: 'Your Daily Digest ☕',
      body,
    })

    if (result === 'stale_token') {
      staleTokenIds.push(user.id)
      failed++
    } else if (result === 'ok') {
      sent++
    } else {
      failed++
    }
  }

  // Clear stale tokens so we don't keep trying them
  if (staleTokenIds.length) {
    await supabase
      .from('users')
      .update({ fcm_token: null })
      .in('id', staleTokenIds)
    console.log(`Cleared ${staleTokenIds.length} stale FCM tokens`)
  }

  const summary = { sent, skipped, failed }
  console.log('Daily digest complete:', summary)
  return new Response(JSON.stringify(summary), {
    headers: { 'Content-Type': 'application/json' },
  })
})

async function sendFcmMessage(
  token: string,
  accessToken: string,
  notification: { title: string; body: string },
): Promise<'ok' | 'stale_token' | 'error'> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification,
          data: { type: 'daily_digest' },
        },
      }),
    },
  )

  if (res.ok) return 'ok'

  const err = await res.json()
  const status = err?.error?.status
  if (status === 'NOT_FOUND' || status === 'INVALID_ARGUMENT') return 'stale_token'

  console.error('FCM send error:', JSON.stringify(err))
  return 'error'
}

// Generates an OAuth2 access token from a Firebase service account using
// the Web Crypto API (available natively in Deno — no extra libraries needed).
async function getFcmAccessToken(serviceAccount: {
  client_email: string
  private_key: string
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000)

  const header = { alg: 'RS256', typ: 'JWT' }
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const b64url = (obj: object) =>
    btoa(JSON.stringify(obj))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '')

  const unsigned = `${b64url(header)}.${b64url(payload)}`

  // Strip PEM headers and decode to DER bytes
  const pemBody = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  const keyDer = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0))

  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    keyDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )

  const sigBuffer = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(unsigned),
  )

  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuffer)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '')

  const jwt = `${unsigned}.${sig}`

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const { access_token } = await tokenRes.json()
  return access_token
}
