import { createClient } from 'jsr:@supabase/supabase-js@2'
import { JWT } from 'npm:google-auth-library@9'

// This function is called by pg_cron every 10 minutes.
// It checks which members are due for a water notification and sends FCM.
Deno.serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  const now = new Date()
  const currentHour = now.getUTCHours() + 3 // Turkey time (UTC+3)
  const adjustedHour = currentHour >= 24 ? currentHour - 24 : currentHour

  // Don't send between 23:00 - 08:00 Turkey time
  if (adjustedHour >= 23 || adjustedHour < 8) {
    return new Response(
      JSON.stringify({ skipped: 'Night hours', hour: adjustedHour }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Get members with water notifications enabled
  // who are due for a notification (last_notified + interval <= now)
  const { data: members, error } = await supabase
    .from('members')
    .select('id, water_interval_minutes, water_last_notified_at')
    .eq('water_notification_enabled', true)
    .not('water_interval_minutes', 'is', null)

  if (error || !members || members.length === 0) {
    return new Response(
      JSON.stringify({ sent: 0, error: error?.message }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Filter members who are due
  const dueMembers = members.filter((m) => {
    const intervalMs = (m.water_interval_minutes ?? 60) * 60 * 1000
    if (!m.water_last_notified_at) return true // Never notified → send now
    const lastNotified = new Date(m.water_last_notified_at).getTime()
    return now.getTime() - lastNotified >= intervalMs
  })

  if (dueMembers.length === 0) {
    return new Response(
      JSON.stringify({ sent: 0, message: 'No members due yet' }),
      { headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Load Firebase credentials
  const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') ?? '{}')
  const jwtClient = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  })
  const accessToken = await jwtClient.getAccessToken()

  let sentCount = 0
  const errors: string[] = []

  for (const member of dueMembers) {
    // Get FCM tokens for this member (Android only — iOS uses local notifications)
    const { data: tokens } = await supabase
      .from('fcm_tokens')
      .select('token, device_type')
      .eq('user_id', member.id)
      .eq('device_type', 'android') // Only Android — iOS handles its own local notifications

    if (!tokens || tokens.length === 0) continue

    // Send FCM to each Android token
    const results = await Promise.all(
      tokens.map(async (t) => {
        try {
          const res = await fetch(
            `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                Authorization: `Bearer ${accessToken.token}`,
              },
              body: JSON.stringify({
                message: {
                  token: t.token,
                  notification: {
                    title: 'Su Vakti! 💧',
                    body: 'Vücudunun suya ihtiyacı var, bir bardak su içmeyi unutma!',
                  },
                  android: {
                    priority: 'high',
                    notification: {
                      channel_id: 'high_importance_channel',
                      sound: 'default',
                    },
                  },
                  data: {
                    type: 'water_reminder',
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  },
                },
              }),
            }
          )
          const json = await res.json()
          if (json.error) errors.push(json.error.message)
          else sentCount++
          return json
        } catch (e) {
          errors.push(String(e))
          return null
        }
      })
    )

    // Update last notified timestamp
    await supabase
      .from('members')
      .update({ water_last_notified_at: now.toISOString() })
      .eq('id', member.id)
  }

  return new Response(
    JSON.stringify({ sent: sentCount, due: dueMembers.length, errors }),
    { headers: { 'Content-Type': 'application/json' } }
  )
})
