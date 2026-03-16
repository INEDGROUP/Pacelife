import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
const WEATHERKIT_KEY = Deno.env.get("WEATHERKIT_JWT")!

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    const { data: users } = await supabase
      .from("profiles")
      .select("id, last_location_lat, last_location_lng, name")
      .not("last_location_lat", "is", null)

    for (const user of users || []) {
      if (!user.last_location_lat || !user.last_location_lng) continue

      const { data: settings } = await supabase
        .from("notification_settings")
        .select("weather_alerts")
        .eq("user_id", user.id)
        .single()

      if (!settings?.weather_alerts) continue

      const { data: todayCheckin } = await supabase
        .from("checkins")
        .select("energy")
        .eq("user_id", user.id)
        .gte("checked_in_at", new Date().toISOString().split("T")[0] + "T00:00:00Z")
        .limit(1)
        .single()

      if (!todayCheckin || todayCheckin.energy < 70) continue

      const weatherUrl = `https://weatherkit.apple.com/api/v1/weather/en/${user.last_location_lat}/${user.last_location_lng}?dataSets=currentWeather&timezone=Europe/London`

      const weatherResponse = await fetch(weatherUrl, {
        headers: { "Authorization": `Bearer ${WEATHERKIT_KEY}` }
      })

      if (!weatherResponse.ok) continue

      const weather = await weatherResponse.json()
      const current = weather.currentWeather
      const temp = Math.round(current.temperature)
      const condition = current.conditionCode

      const isGoodWeather = !["Rain", "Snow", "Thunderstorm", "Hail"].some(c => condition.includes(c))
      const isGoodTemp = temp >= 10 && temp <= 28

      if (isGoodWeather && isGoodTemp) {
        const firstName = user.name?.split(" ")[0] || "there"
        await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`
          },
          body: JSON.stringify({
            user_id: user.id,
            title: "Perfect conditions right now ☀️",
            body: `${temp}°C and ${condition.toLowerCase().replace(/([A-Z])/g, " $1").trim()} outside. Great time for a walk, ${firstName}!`,
            type: "weather_alert",
            data: { temperature: temp, condition }
          })
        })
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" }
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
