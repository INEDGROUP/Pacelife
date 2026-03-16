import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

function getLocalHour(timezone: string): number {
  try {
    const localTime = new Intl.DateTimeFormat("en-US", {
      timeZone: timezone,
      hour: "numeric",
      hour12: false,
    }).format(new Date())
    return parseInt(localTime, 10)
  } catch {
    return new Date().getUTCHours()
  }
}

function isQuietHours(timezone: string, quietStart: number, quietEnd: number): boolean {
  const hour = getLocalHour(timezone)
  if (quietStart > quietEnd) {
    return hour >= quietStart || hour < quietEnd
  }
  return hour >= quietStart && hour < quietEnd
}

function hasAlreadySentToday(lastSent: string | null, timezone: string): boolean {
  if (!lastSent) return false
  try {
    const lastDate = new Date(lastSent)
    const todayLocal = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone,
    }).format(new Date())
    const lastLocal = new Intl.DateTimeFormat("en-CA", {
      timeZone: timezone,
    }).format(lastDate)
    return todayLocal === lastLocal
  } catch {
    return false
  }
}

async function sendPush(supabase: any, userId: string, title: string, body: string, type: string, data: object = {}) {
  const response = await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
    },
    body: JSON.stringify({ user_id: userId, title, body, type, data }),
  })
  return response.ok
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const { type } = await req.json()

    const { data: allSettings } = await supabase
      .from("notification_settings")
      .select("user_id, morning_checkin, morning_checkin_time, evening_insight, evening_insight_time, streak_reminder, ai_patterns, quiet_hours_start, quiet_hours_end, user_timezone")

    for (const settings of allSettings || []) {
      const timezone = settings.user_timezone || "Europe/London"
      const localHour = getLocalHour(timezone)
      const quietStart = settings.quiet_hours_start ?? 22
      const quietEnd = settings.quiet_hours_end ?? 8

      if (isQuietHours(timezone, quietStart, quietEnd)) continue

      if (type === "morning_checkin_hourly") {
        if (!settings.morning_checkin) continue
        const checkinTime = settings.morning_checkin_time || "08:00"
        const checkinHour = parseInt(checkinTime.split(":")[0], 10)
        if (localHour !== checkinHour) continue

        const { data: lastNotif } = await supabase
          .from("notifications")
          .select("sent_at")
          .eq("user_id", settings.user_id)
          .eq("type", "morning_checkin")
          .order("sent_at", { ascending: false })
          .limit(1)
          .single()

        if (hasAlreadySentToday(lastNotif?.sent_at, timezone)) continue

        const { data: todayCheckin } = await supabase
          .from("checkins")
          .select("id")
          .eq("user_id", settings.user_id)
          .gte("checked_in_at", new Date(new Date().setHours(0, 0, 0, 0)).toISOString())
          .limit(1)

        if (todayCheckin && todayCheckin.length > 0) continue

        const { data: profile } = await supabase
          .from("profiles")
          .select("name")
          .eq("id", settings.user_id)
          .single()

        const firstName = profile?.name?.split(" ")[0] || "there"
        const greetings = [
          `Good morning, ${firstName}. How's your energy today?`,
          `Morning ${firstName}! Time for your daily check-in`,
          `Rise and shine, ${firstName}. Log your energy to unlock today's insights`,
          `Hey ${firstName}, start your day with a quick check-in`,
        ]
        const greeting = greetings[new Date().getDay() % greetings.length]

        await sendPush(supabase, settings.user_id, "PaceLife", greeting, "morning_checkin")
        console.log(`Morning checkin sent to ${settings.user_id} in ${timezone} at local hour ${localHour}`)
      }

      if (type === "evening_insights_hourly") {
        if (!settings.evening_insight) continue
        const insightTime = settings.evening_insight_time || "20:00"
        const insightHour = parseInt(insightTime.split(":")[0], 10)
        if (localHour !== insightHour) continue

        const { data: lastNotif } = await supabase
          .from("notifications")
          .select("sent_at")
          .eq("user_id", settings.user_id)
          .eq("type", "evening_insight")
          .order("sent_at", { ascending: false })
          .limit(1)
          .single()

        if (hasAlreadySentToday(lastNotif?.sent_at, timezone)) continue

        const { data: checkins } = await supabase
          .from("checkins")
          .select("energy, sleep_hours, mood, checked_in_at")
          .eq("user_id", settings.user_id)
          .order("checked_in_at", { ascending: false })
          .limit(7)

        if (!checkins || checkins.length === 0) continue

        const todayCheckin = checkins[0]
        const avgEnergy = Math.round(checkins.reduce((a: number, c: any) => a + c.energy, 0) / checkins.length)

        const aiResponse = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": ANTHROPIC_API_KEY,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: "claude-sonnet-4-20250514",
            max_tokens: 100,
            messages: [{
              role: "user",
              content: `Generate a short evening insight (max 100 chars) for a user. Today energy: ${todayCheckin.energy}, week average: ${avgEnergy}. Be specific and motivating. No emojis.`,
            }],
          }),
        })

        const aiData = await aiResponse.json()
        const insight = aiData.content?.[0]?.text || "Great effort today. Rest well tonight."

        await sendPush(supabase, settings.user_id, "Your evening insight", insight, "evening_insight", {
          energy: todayCheckin.energy,
          avg_energy: avgEnergy,
        })
        console.log(`Evening insight sent to ${settings.user_id} in ${timezone} at local hour ${localHour}`)
      }

      if (type === "streak_check_hourly") {
        if (!settings.streak_reminder) continue
        if (localHour !== 21) continue

        const { data: profile } = await supabase
          .from("profiles")
          .select("streak_days")
          .eq("id", settings.user_id)
          .single()

        if (!profile || profile.streak_days === 0) continue

        const { data: lastNotif } = await supabase
          .from("notifications")
          .select("sent_at")
          .eq("user_id", settings.user_id)
          .eq("type", "streak_reminder")
          .order("sent_at", { ascending: false })
          .limit(1)
          .single()

        if (hasAlreadySentToday(lastNotif?.sent_at, timezone)) continue

        const { data: todayCheckin } = await supabase
          .from("checkins")
          .select("id")
          .eq("user_id", settings.user_id)
          .gte("checked_in_at", new Date(new Date().setHours(0, 0, 0, 0)).toISOString())
          .limit(1)

        if (todayCheckin && todayCheckin.length > 0) continue

        await sendPush(
          supabase,
          settings.user_id,
          `Don't lose your ${profile.streak_days}-day streak!`,
          "Log today's check-in before midnight to keep your streak alive.",
          "streak_reminder",
          { streak_days: profile.streak_days }
        )
        console.log(`Streak reminder sent to ${settings.user_id} in ${timezone}`)
      }

      if (type === "ai_patterns") {
        if (!settings.ai_patterns) continue
        if (localHour !== 15) continue

        const { data: checkins } = await supabase
          .from("checkins")
          .select("energy, sleep_hours, mood, checked_in_at")
          .eq("user_id", settings.user_id)
          .order("checked_in_at", { ascending: false })
          .limit(14)

        if (!checkins || checkins.length < 5) continue

        const recentAvg = checkins.slice(0, 3).reduce((a: number, c: any) => a + c.energy, 0) / 3
        const prevAvg = checkins.slice(3, 6).reduce((a: number, c: any) => a + c.energy, 0) / 3

        if (recentAvg >= prevAvg - 15) continue

        const { data: lastPattern } = await supabase
          .from("notifications")
          .select("sent_at")
          .eq("user_id", settings.user_id)
          .eq("type", "ai_pattern")
          .order("sent_at", { ascending: false })
          .limit(1)
          .single()

        const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000)
        if (lastPattern?.sent_at && new Date(lastPattern.sent_at) > twoDaysAgo) continue

        const aiResponse = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": ANTHROPIC_API_KEY,
            "anthropic-version": "2023-06-01",
          },
          body: JSON.stringify({
            model: "claude-sonnet-4-20250514",
            max_tokens: 120,
            messages: [{
              role: "user",
              content: `Energy dropped ${Math.round(prevAvg - recentAvg)} points over 3 days (from ${Math.round(prevAvg)} to ${Math.round(recentAvg)}). Write a caring notification (max 110 chars) with a specific recovery tip. No emojis.`,
            }],
          }),
        })

        const aiData = await aiResponse.json()
        const tip = aiData.content?.[0]?.text || "Your energy has been lower this week. Try an early night tonight."

        await sendPush(supabase, settings.user_id, "Energy pattern detected", tip, "ai_pattern", {
          energy_trend: recentAvg,
          prev_trend: prevAvg,
        })
        console.log(`AI pattern sent to ${settings.user_id} in ${timezone}`)
      }
    }

    return new Response(
      JSON.stringify({ success: true, processed: type }),
      { headers: { "Content-Type": "application/json", ...corsHeaders } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    )
  }
})
