-- Schedule the cron jobs if pg_cron is available
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
    ) THEN
        -- Remove existing jobs if they exist
        PERFORM cron.unschedule('queue-reminder-emails');
        PERFORM cron.unschedule('sending email');
        
        -- Schedule reminder emails job to run every 5 minutes
        PERFORM cron.schedule(
            'queue-reminder-emails',
            '*/5 * * * *',  -- Every 5 minutes
            $$SELECT public.queue_reminder_emails();$$
        );

        -- Schedule email sending job to run every 5 minutes
        PERFORM cron.schedule(
            'sending email',
            '*/5 * * * *',  -- Every 5 minutes
            $$
            select
              net.http_post(
                  url:='https://nimnhhqjjzpnhhecnuqm.supabase.co/functions/v1/helloEmail',
                  headers:=jsonb_build_object('Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5pbW5oaHFqanpwbmhoZWNudXFtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNDk0MDExNiwiZXhwIjoyMDUwNTE2MTE2fQ.mp9lSUzCeWQxTwe18zU1XbeyWWY-P5Rr-T2Pw-t5ef8'),
                  timeout_milliseconds:=1000
              );
            $$
        );
    END IF;
END $$;

-- Create a function to manually check job status
CREATE OR REPLACE FUNCTION check_email_reminder_status()
RETURNS TABLE (
    status TEXT,
    count BIGINT,
    last_run TIMESTAMPTZ
)
LANGUAGE sql
AS $$
    SELECT 
        el.status,
        COUNT(*),
        MAX(el.updated_at) as last_run
    FROM email_logs el
    WHERE el.email_type = 'report_reminder'
    AND el.updated_at > NOW() - INTERVAL '24 hours'
    GROUP BY el.status;
$$; 