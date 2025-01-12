-- Create tables for the public schema
create or replace table public.users (
    id uuid primary key default uuid_generate_v4(),
    email text not null unique,
    username text not null,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create or replace table public.reports (
    id uuid primary key default uuid_generate_v4(),
    report_text text not null,
    status text,
    reviewer_notes text,
    reviewed_at timestamptz,
    submission_timestamp timestamptz,
    user_id uuid references public.users(id),
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

create or replace table public.email_logs (
    id uuid primary key default uuid_generate_v4(),
    user_id uuid references public.users(id),
    email_type text not null,
    status text,
    error_message text,
    metadata jsonb,
    sent_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);

-- Create updated_at trigger function
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

-- Add updated_at triggers
create or replace trigger handle_users_updated_at
    before update on public.users
    for each row
    execute function public.handle_updated_at();

create or replace trigger handle_reports_updated_at
    before update on public.reports
    for each row
    execute function public.handle_updated_at();

create or replace trigger handle_email_logs_updated_at
    before update on public.email_logs
    for each row
    execute function public.handle_updated_at();

-- Enable RLS
alter table public.users enable row level security;
alter table public.reports enable row level security;
alter table public.email_logs enable row level security; 