-- Create email_logs table
CREATE TABLE IF NOT EXISTS public.email_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email_type TEXT NOT NULL,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'pending' 
        CHECK (status IN ('pending', 'success', 'failed')),
    error_message TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Set up RLS policies
ALTER TABLE public.email_logs ENABLE ROW LEVEL SECURITY;

-- Allow users to see their own email logs
CREATE POLICY "Users can view own email logs"
    ON public.email_logs FOR SELECT
    USING (auth.uid() = user_id);

-- Allow the service role to manage all email logs
CREATE POLICY "Service role can manage all email logs"
    ON public.email_logs FOR ALL
    USING (auth.jwt()->>'role' = 'service_role'); 