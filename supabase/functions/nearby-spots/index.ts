import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!

function distanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLon = (lon2 - lon1) * Math.PI / 180
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2)
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    const { user_id, latitude, longitude } = await req.json()

    const { data: settings } = await supabase
      .from("notification_settings")
      .select("weather_alerts")
      .eq("user_id", user_id)
      .single()

    if (!settings?.weather_alerts) {
      return new Response(JSON.stringify({ skipped: true }), { headers: { "Content-Type": "application/json" } })
    }

    const { data: spots } = await supabase
      .from("spots")
      .select("id, title, category, latitude, longitude, visit_count")
      .eq("user_id", user_id)

    if (!spots || spots.length === 0) {
      return new Response(JSON.stringify({ no_spots: true }), { headers: { "Content-Type": "application/json" } })
    }

    const nearby = spots.filter(spot => {
      const dist = distanceKm(latitude, longitude, spot.latitude, spot.longitude)
      return dist < 0.3
    })

    if (nearby.length === 0) {
      return new Response(JSON.stringify({ no_nearby: true }), { headers: { "Content-Type": "application/json" } })
    }

    const spot = nearby.sort((a, b) => b.visit_count - a.visit_count)[0]

    const lastNotif = await supabase
      .from("notifications")
      .select("id")
      .eq("user_id", user_id)
      .eq("type", "nearby_spot")
      .gte("sent_at", new Date(Date.now() - 4 * 60 * 60 * 1000).toISOString())

    if (lastNotif.data && lastNotif.data.length > 0) {
      return new Response(JSON.stringify({ throttled: true }), { headers: { "Content-Type": "application/json" } })
    }

    await fetch(`${SUPABASE_URL}/functions/v1/send-push`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`
      },
      body: JSON.stringify({
        user_id,
        title: `You're near ${spot.title} 📍`,
        body: `One of your favourite ${spot.category} spots is just around the corner.`,
        type: "nearby_spot",
        data: { spot_id: spot.id, spot_title: spot.title }
      })
    })

    return new Response(JSON.stringify({ notified: true, spot: spot.title }), {
      headers: { "Content-Type": "application/json" }
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }
})
