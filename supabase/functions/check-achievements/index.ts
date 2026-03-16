import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

const ACHIEVEMENTS = [
  { type: "first_checkin", title: "First check-in! 🎉", body: "You've taken the first step. Keep it up!" },
  { type: "streak_3", title: "3-day streak! 🔥", body: "You're building momentum. Don't stop now!" },
  { type: "streak_7", title: "7-day streak! 🔥", body: "One full week! You're in the top 20% of PaceLife users." },
  { type: "streak_14", title: "14-day streak! 💪", body: "Two weeks straight. This is becoming a real habit." },
  { type: "streak_30", title: "30-day streak! 🏆", body: "Incredible. You're in the top 5% of PaceLife users." },
  { type: "streak_100", title: "100-day streak! 🌟", body: "You're legendary. 100 days of consistent tracking!" },
  { type: "first_route", title: "First route recorded! 🗺️", body: "Your city is your gym. Keep exploring!" },
  { type: "routes_10", title: "10 routes! 🏃", body: "You've covered some serious ground. Explorer badge earned!" },
  { type: "steps_10k", title: "10,000 steps! 👟", body: "Daily goal crushed. Your body thanks you." },
]

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const { user_id } = await req.json()

    const { data: earned } = await supabase
      .from("achievements")
      .select("type")
      .eq("user_id", user_id)

    const earnedTypes = new Set(earned?.map(a => a.type) || [])

    const { data: profile } = await supabase
      .from("profiles")
      .select("streak_days, total_checkins")
      .eq("id", user_id)
      .single()

    const { data: routes } = await supabase
      .from("routes")
      .select("id")
      .eq("user_id", user_id)

    const streakDays = profile?.streak_days || 0
    const totalCheckins = profile?.total_checkins || 0
    const totalRoutes = routes?.length || 0

    const toAward: string[] = []

    if (totalCheckins === 1 && !earnedTypes.has("first_checkin")) toAward.push("first_checkin")
    if (streakDays >= 3 && !earnedTypes.has("streak_3")) toAward.push("streak_3")
    if (streakDays >= 7 && !earnedTypes.has("streak_7")) toAward.push("streak_7")
    if (streakDays >= 14 && !earnedTypes.has("streak_14")) toAward.push("streak_14")
    if (streakDays >= 30 && !earnedTypes.has("streak_30")) toAward.push("streak_30")
    if (streakDays >= 100 && !earnedTypes.has("streak_100")) toAward.push("streak_100")
    if (totalRoutes === 1 && !earnedTypes.has("first_route")) toAward.push("first_route")
    if (totalRoutes >= 10 && !earnedTypes.has("routes_10")) toAward.push("routes_10")

    for (const achievementType of toAward) {
      const achievement = ACHIEVEMENTS.find(a => a.type === achievementType)
      if (!achievement) continue

      await supabase.from("achievements").insert({
        user_id,
        type: achievement.type,
        title: achievement.title
      })

      await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`
        },
        body: JSON.stringify({
          user_id,
          title: achievement.title,
          body: achievement.body,
          type: "achievement",
          data: { achievement_type: achievementType }
        })
      })
    }

    return new Response(
      JSON.stringify({ awarded: toAward }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
