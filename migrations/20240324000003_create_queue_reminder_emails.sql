-- Create function to queue reminder emails
CREATE OR REPLACE FUNCTION public.queue_reminder_emails()
RETURNS INTEGER 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    inactive_count INTEGER;
BEGIN
    -- First, reset failed emails to pending for retry
    UPDATE email_logs
    SET 
        status = 'pending',
        error_message = NULL,
        updated_at = NOW()
    WHERE 
        status = 'failed'
        AND email_type = 'report_reminder'
        AND updated_at < NOW() - INTERVAL '5 minutes';

    -- Then queue new emails for inactive users
    INSERT INTO email_logs (
        user_id,
        email_type,
        status,
        metadata
    )
    SELECT 
        user_id,
        'report_reminder',
        'pending',
        jsonb_build_object(
            'email', email,
            'username', username,
            'last_report_time', last_report_time
        )
    FROM identify_inactive_users();

    GET DIAGNOSTICS inactive_count = ROW_COUNT;
    RETURN inactive_count;
END;
$$; 