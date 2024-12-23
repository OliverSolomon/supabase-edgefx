-- Add submission_timestamp to reports if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'reports' 
        AND column_name = 'submission_timestamp'
    ) THEN
        ALTER TABLE public.reports 
        ADD COLUMN submission_timestamp TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$; 