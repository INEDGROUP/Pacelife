import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const { user_id, weather_temp, weather_condition, steps } = await req.json()

    const { data: checkins } = await supabase
      .from("checkins")
      .select("energy, sleep_hours, mood, notes, checked_in_at")
      .eq("user_id", user_id)
      .order("checked_in_at", { ascending: false })
      .limit(14)

    const { data: profile } = await supabase
      .from("profiles")
      .select("name, goals, streak_days, height_cm, weight_kg, date_of_birth")
      .eq("id", user_id)
      .single()

    const { data: spots } = await supabase
      .from("spots")
      .select("title, category")
      .eq("user_id", user_id)
      .limit(5)

    if (!checkins || checkins.length === 0) {
      return new Response(
        JSON.stringify({ insight: "Log your first check-in to unlock personalised AI insights." }),
        { headers: { "Content-Type": "application/json" } }
      )
    }

    const today = checkins[0]
    const avgEnergy = Math.round(checkins.reduce((a, c) => a + c.energy, 0) / checkins.length)
    const sleepCheckins = checkins.filter(c => c.sleep_hours)
    const avgSleep = sleepCheckins.length > 0
      ? sleepCheckins.reduce((a, c) => a + (c.sleep_hours || 0), 0) / sleepCheckins.length
      : null

    const age = profile?.date_of_birth
      ? Math.floor((Date.now() - new Date(profile.date_of_birth).getTime()) / (365.25 * 24 * 60 * 60 * 1000))
      : null

    const weatherLine = weather_temp != null && weather_condition
      ? `- Weather: ${weather_temp}°C, ${weather_condition}`
      : "- Weather: unknown"

    const stepsLine = steps != null && steps > 0
      ? `- Steps so far today: ${steps.toLocaleString()}`
      : "- Steps: not available"

    const spotsLine = spots && spots.length > 0
      ? `- Saved spots nearby: ${spots.map((s: { title: string; category: string }) => s.title).join(", ")}`
      : ""

    const prompt = `You are PaceLife AI, a personal energy and wellness coach. Analyze this user's data and provide a specific, actionable daily insight.

User profile:
- Name: ${profile?.name?.split(" ")[0] || "User"}
- Age: ${age || "unknown"}
- Goals: ${profile?.goals?.join(", ") || "general wellness"}
- Current streak: ${profile?.streak_days || 0} days

Today's check-in:
- Energy: ${today.energy}/100
- Sleep: ${today.sleep_hours || "not logged"}h
- Mood: ${today.mood || "not logged"}/5
${stepsLine}
${weatherLine}
${spotsLine}

14-day averages:
- Average energy: ${avgEnergy}/100
- Average sleep: ${avgSleep ? avgSleep.toFixed(1) : "unknown"}h

Recent trend: ${checkins.slice(0, 3).map(c => c.energy).join(", ")} (last 3 days)

Write ONE insight (2-3 sentences max, 150 chars max). Be specific to their data. Reference the weather or steps if relevant. If they have saved spots, suggest one if appropriate. No generic advice. Address them by first name. Focus on what they should do TODAY based on their energy level. Don't use emojis.`

    const aiResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01"
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 200,
        messages: [{ role: "user", content: prompt }]
      })
    })

    const aiData = await aiResponse.json()
    const insight = aiData.content[0]?.text || "Great data today. Keep up your check-in streak for deeper insights."

    await supabase.from("ai_insights").insert({
      user_id,
      type: "daily",
      title: "Today's insight",
      body: insight,
      metadata: {
        energy: today.energy,
        avg_energy: avgEnergy,
        streak: profile?.streak_days || 0,
        weather_temp,
        weather_condition,
        steps
      }
    })

    return new Response(
      JSON.stringify({ insight }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
