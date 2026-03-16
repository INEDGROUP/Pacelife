import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID")!
const APNS_PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!

async function generateAPNSJWT(): Promise<string> {
  const header = { alg: "ES256", kid: APNS_KEY_ID }
  const payload = { iss: APNS_TEAM_ID, iat: Math.floor(Date.now() / 1000) }

  const encoder = new TextEncoder()
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")
  const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")
  const signingInput = `${headerB64}.${payloadB64}`

  const pemContents = APNS_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "")
    .trim()

  const keyData = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  )

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    cryptoKey,
    encoder.encode(signingInput)
  )

  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")

  return `${signingInput}.${signatureB64}`
}

async function sendAPNS(token: string, payload: object, isProduction = true): Promise<boolean> {
  const jwt = await generateAPNSJWT()
  const host = isProduction ? "api.push.apple.com" : "api.sandbox.push.apple.com"
  const url = `https://${host}/3/device/${token}`

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json"
    },
    body: JSON.stringify(payload)
  })

  if (!response.ok) {
    const error = await response.text()
    console.error(`APNS error: ${response.status} ${error}`)
    return false
  }
  return true
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const { user_id, title, body, data, type } = await req.json()

    const { data: tokens } = await supabase
      .from("push_tokens")
      .select("token, is_production")
      .eq("user_id", user_id)
      .eq("is_active", true)

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ error: "No tokens found" }), { status: 404 })
    }

    const payload = {
      aps: {
        alert: { title, body },
        sound: "default",
        badge: 1,
        "mutable-content": 1
      },
      type,
      ...data
    }

    const results = await Promise.all(
      tokens.map(async ({ token, is_production }) => {
        const useProduction = is_production ?? false
        const success = await sendAPNS(token, payload, useProduction)
        return success
      })
    )

    await supabase.from("notifications").insert({
      user_id,
      type: type || "push",
      title,
      body,
      data: data || {}
    })

    return new Response(
      JSON.stringify({ success: true, sent: results.filter(Boolean).length }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
