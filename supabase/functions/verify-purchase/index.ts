import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    const body = await req.json()
    const {
      user_id,
      transaction_id,
      original_transaction_id,
      product_id,
      purchase_date,
      expires_date,
      environment
    } = body

    console.log(`verify-purchase: user=${user_id} product=${product_id} env=${environment}`)

    if (!user_id || !transaction_id || !product_id) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      )
    }

    const isAnnual = product_id.includes("annual")
    const plan = isAnnual ? "annual" : "monthly"

    const purchaseDateObj = new Date(purchase_date * 1000)
    const expiresDateObj = expires_date ? new Date(expires_date * 1000) : null
    const now = new Date()
    const isActive = expiresDateObj ? expiresDateObj > now : true

    console.log(`verify-purchase: plan=${plan} active=${isActive} expires=${expiresDateObj}`)

    const { error: subError } = await supabase
      .from("subscriptions")
      .upsert({
        user_id,
        status: isActive ? "active" : "expired",
        plan,
        apple_original_transaction_id: original_transaction_id || transaction_id,
        apple_product_id: product_id,
        current_period_start: purchaseDateObj.toISOString(),
        current_period_end: expiresDateObj?.toISOString() || null,
        expires_at: expiresDateObj?.toISOString() || null,
        environment: (environment || "sandbox").toLowerCase(),
        updated_at: new Date().toISOString()
      }, {
        onConflict: "user_id"
      })

    if (subError) {
      console.error("verify-purchase: subscription upsert error:", subError)
    } else {
      console.log("verify-purchase: subscription updated successfully")
    }

    const { error: txError } = await supabase
      .from("subscription_transactions")
      .upsert({
        user_id,
        transaction_id: String(transaction_id),
        original_transaction_id: String(original_transaction_id || transaction_id),
        product_id,
        purchase_date: purchaseDateObj.toISOString(),
        expires_date: expiresDateObj?.toISOString() || null,
        transaction_type: "purchase",
        environment: (environment || "sandbox").toLowerCase(),
        raw_data: body
      }, {
        onConflict: "transaction_id"
      })

    if (txError) {
      console.error("verify-purchase: transaction insert error:", txError)
    } else {
      console.log("verify-purchase: transaction recorded successfully")
    }

    if (isActive) {
      await supabase
        .from("notification_settings")
        .update({ trial_reminders: false })
        .eq("user_id", user_id)
    }

    return new Response(
      JSON.stringify({
        success: true,
        status: isActive ? "active" : "expired",
        plan,
        expires_at: expiresDateObj?.toISOString()
      }),
      { headers: { "Content-Type": "application/json", ...corsHeaders } }
    )
  } catch (error) {
    console.error("verify-purchase error:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    )
  }
}, {
  onError: (error) => {
    console.error("verify-purchase fatal error:", error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
