ALTER TABLE members 
ADD COLUMN IF NOT EXISTS water_interval_minutes INTEGER DEFAULT 60,
ADD COLUMN IF NOT EXISTS water_last_notified_at TIMESTAMPTZ;

UPDATE members 
SET water_interval_minutes = 60 
WHERE water_interval_minutes IS NULL;

UPDATE members
SET water_notification_enabled = true
WHERE water_notification_enabled IS NULL;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Unschedules the cron job if it already exists to avoid duplicates
SELECT cron.unschedule('send-water-reminders');

-- Schedule the cron job to call the edge function every 10 minutes
SELECT cron.schedule(
  'send-water-reminders',
  '*/10 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://hrywsorgjitwedsnlbyp.supabase.co/functions/v1/send-water-reminders',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
