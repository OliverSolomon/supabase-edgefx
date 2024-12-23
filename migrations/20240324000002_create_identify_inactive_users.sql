-- Create function to identify users needing reminders
CREATE OR REPLACE FUNCTION public.identify_inactive_users()
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    username TEXT,
    last_report_time TIMESTAMPTZ
)
AS $$
    WITH user_reports AS (
        -- Get latest report for each user
        SELECT 
            u.id as user_id,
            au.email,
            u.username,
            MAX(r.submission_timestamp) as last_report_time
        FROM public.users u
        JOIN auth.users au ON u.id = au.id
        LEFT JOIN reports r ON u.id = r.user_id
        GROUP BY u.id, au.email, u.username
    ),
    latest_emails AS (
        -- Get latest reminder email for each user
        SELECT 
            user_id,
            MAX(sent_at) as last_email_sent
        FROM email_logs
        WHERE email_type = 'report_reminder'
        AND status IN ('success', 'pending')
        GROUP BY user_id
    )
    SELECT 
        ur.user_id,
        ur.email,
        ur.username,
        ur.last_report_time
    FROM user_reports ur
    LEFT JOIN latest_emails le ON ur.user_id = le.user_id
    WHERE 
        -- Include users with no reports OR reports older than 5 minutes
        (ur.last_report_time IS NULL OR ur.last_report_time < NOW() - INTERVAL '5 minutes')
        AND (
            -- No previous reminder email OR last reminder was more than 1 hour ago
            le.last_email_sent IS NULL 
            OR le.last_email_sent < NOW() - INTERVAL '1 hour'
        );
$$ LANGUAGE sql SECURITY DEFINER; 