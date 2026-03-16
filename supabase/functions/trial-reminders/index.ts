import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const now = new Date()
    const in3Days = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000)
    const in1Day = new Date(now.getTime() + 1 * 24 * 60 * 60 * 1000)

    const { data: expiring3 } = await supabase
      .from("subscriptions")
      .select("user_id, trial_ends_at")
      .eq("status", "trial")
      .gte("trial_ends_at", now.toISOString())
      .lte("trial_ends_at", in3Days.toISOString())

    for (const sub of expiring3 || []) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("streak_days")
        .eq("id", sub.user_id)
        .single()

      const { data: settings } = await supabase
        .from("notification_settings")
        .select("trial_reminders")
        .eq("user_id", sub.user_id)
        .single()

      if (!settings?.trial_reminders) continue

      const alreadySent = await supabase
        .from("notifications")
        .select("id")
        .eq("user_id", sub.user_id)
        .eq("type", "trial_3days")
        .gte("sent_at", new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString())

      if (alreadySent.data && alreadySent.data.length > 0) continue

      await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`
        },
        body: JSON.stringify({
          user_id: sub.user_id,
          title: "3 days left in your trial",
          body: `Don't lose your ${profile?.streak_days || 0}-day streak and insights. Upgrade to PaceLife Pro.`,
          type: "trial_3days"
        })
      })
    }

    const { data: expiring1 } = await supabase
      .from("subscriptions")
      .select("user_id, trial_ends_at")
      .eq("status", "trial")
      .gte("trial_ends_at", now.toISOString())
      .lte("trial_ends_at", in1Day.toISOString())

    for (const sub of expiring1 || []) {
      const { data: profile } = await supabase
        .from("profiles")
        .select("streak_days")
        .eq("id", sub.user_id)
        .single()

      const { data: settings } = await supabase
        .from("notification_settings")
        .select("trial_reminders")
        .eq("user_id", sub.user_id)
        .single()

      if (!settings?.trial_reminders) continue

      await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`
        },
        body: JSON.stringify({
          user_id: sub.user_id,
          title: "Last day of your trial ⏰",
          body: `Your ${profile?.streak_days || 0}-day streak ends tomorrow if you don't upgrade. Keep your progress.`,
          type: "trial_1day"
        })
      })
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" }
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
