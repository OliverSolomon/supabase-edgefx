-- Schedule the cron job if pg_cron is available
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
    ) THEN
        PERFORM cron.schedule(
            'queue-reminder-emails',
            '*/5 * * * *',  -- Every 5 minutes
            $$SELECT public.queue_reminder_emails();$$
        );
    END IF;
END $$; 