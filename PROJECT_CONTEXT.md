# PaceLife — Project Context

## App
- **Name:** PaceLife — AI Energy Coach
- **Bundle ID:** com.inedgroup.pacelife
- **iOS:** 26+ only, SwiftUI, dark theme only
- **Path:** ~/Developer/PaceLife/
- **Team ID:** 7XG7U24KK9
- **Company:** Ined Group Ltd
- **Support:** support@inedgroup.com

## Supabase Backend
- **URL:** https://vhgnnujzcjjugbneuwhn.supabase.co
- **Project ref:** vhgnnujzcjjugbneuwhn
- **Anon key:** eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoZ25udWp6Y2pqdWdibmV1d2huIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1ODg5MDgsImV4cCI6MjA4OTE2NDkwOH0.JjtPfC3P1V-pAZ4UrHDSbTNvxIlNHlrL3TCKqfWo4EA
- **Service role key:** eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZoZ25udWp6Y2pqdWdibmV1d2huIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzU4ODkwOCwiZXhwIjoyMDg5MTY0OTA4fQ.3FhwY_D3VwTtHSi84N-x0dl1yAFtiKtRyu4FDvbwyTY

## Database Tables
- profiles — name, goals, avatar_url, streak_days, total_checkins, city, location
- checkins — energy, sleep_hours, mood, notes, checked_in_at
- routes — title, distance_km, duration_minutes, intensity, coordinates, calories
- spots — title, category, latitude, longitude, notes, visit_count
- subscriptions — status, plan, trial_ends_at, expires_at, apple_original_transaction_id
- subscription_transactions — transaction_id, product_id, purchase_date, expires_date
- push_tokens — token, is_active, is_production, user_timezone
- notification_settings — all toggles, quiet_hours, user_timezone
- notifications — type, title, body, sent_at
- ai_insights — type, title, body, metadata
- achievements — type, title, earned_at

## Edge Functions (all deployed with --no-verify-jwt)
- send-push — APNs push notifications
- daily-notifications — timezone-aware morning/evening/streak
- ai-daily-insight — Claude API personalised insights
- nearby-spots — geofence check 4hr throttle
- check-achievements — streak milestones
- trial-reminders — 3-day and 1-day before trial end
- weather-notifications — WeatherKit + energy check
- verify-purchase — StoreKit transaction verification
- apple-notifications — App Store Server Notifications webhook

## StoreKit
- **Monthly:** com.inedgroup.pacelife.monthly — £8.99/month
- **Annual:** com.inedgroup.pacelife.annual — £59.99/year
- **Subscription Group ID:** 21980964
- **Trial:** 7 days free on both products
- **StoreKit config:** PaceLife/PaceLifeProducts.storekit

## APNs
- **Key ID:** D653854T6C
- **Team ID:** 7XG7U24KK9
- **Environment:** development (change to production after App Store approval)

## Screens
- Onboarding (5 pages: Welcome, Name, Goals, Permissions, Paywall)
- Auth (email/password + Sign in with Apple + Forgot Password)
- Home (AI insight card, energy chart, steps, suggested route, weather)
- Map (spots with 8 categories, route recording, See All sheet)
- Insights (energy chart, sleep chart, correlation, route stats, achievements, AI history)
- Profile (avatar, stats, subscription card, notifications, privacy, help, delete account)
- Paywall (StoreKit 2, monthly/annual toggle, success screen)
- CheckinView (energy slider, sleep, mood, HealthKit autofill)

## Design System
- **Colors:** plGreen #4CFFA0, plBlue #6B8FFF, plAmber #FFB347, plRed #FF6B6B
- **Background:** plBg #0A0A0F, plBgSecondary #13131F, plBgTertiary #1A1A2E
- **Typography:** SF Pro Rounded (plSans) + SF Serif (plDisplay)
- **Theme:** Dark only (preferredColorScheme: .dark)
- **Tab bar:** iOS 26 native with Liquid Glass

## App Store
- **Privacy Policy:** https://inedgroup.github.io/Pacelife/privacy.html
- **Support:** https://inedgroup.github.io/Pacelife/support.html
- **GitHub:** https://github.com/INEDGROUP/Pacelife
- **Category:** Health & Fitness
- **Age Rating:** 4+
- **Price:** Free with subscription

## Test Account
- **Email:** reviewer@pacelife.app
- **Password:** ReviewPaceLife2026!
- **My userId:** 638fc718-bc56-43c7-b382-592c36c88fec

## Build Commands
cd ~/Developer/PaceLife && xcodegen generate
sed -i '' 's/DEVELOPMENT_TEAM = "";/DEVELOPMENT_TEAM = 7XG7U24KK9;/g' ~/Developer/PaceLife/PaceLife.xcodeproj/project.pbxproj

## Deploy Edge Function
supabase functions deploy [name] --project-ref vhgnnujzcjjugbneuwhn --no-verify-jwt

## Known Issues / TODO
- [ ] App Store screenshots needed
- [ ] After App Store approval: change aps-environment to production
- [ ] WeatherKit cron for weather-notifications
- [ ] Subscription images 1024x1024 for Monthly/Annual products
