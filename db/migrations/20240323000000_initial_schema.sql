-- Create users table that references auth.users
create table public.users (
    id uuid references auth.users(id) primary key,
    email text not null,
    username text not null,
    created_at timestamp with time zone default now() not null,
    updated_at timestamp with time zone default now() not null,
    
    -- Add unique constraints
    constraint users_email_unique unique (email),
    constraint users_username_unique unique (username)
);

-- Create reports table
create table public.reports (
    id uuid default gen_random_uuid() primary key,
    user_id uuid references public.users(id) not null,
    report_text text not null,
    status text default 'pending' check (status in ('pending', 'reviewed', 'resolved', 'dismissed')),
    created_at timestamp with time zone default now() not null,
    updated_at timestamp with time zone default now() not null,
    reviewed_at timestamp with time zone,
    reviewer_notes text
);

-- Create RLS (Row Level Security) policies
alter table public.users enable row level security;
alter table public.reports enable row level security;

-- Users can only read their own profile
create policy "Users can view own profile"
    on public.users for select
    using (auth.uid() = id);

-- Users can create reports
create policy "Users can create reports"
    on public.reports for insert
    with check (auth.uid() = user_id);

-- Users can view their own reports
create policy "Users can view own reports"
    on public.reports for select
    using (auth.uid() = user_id);

-- Create triggers for updated_at
create or replace function public.handle_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger handle_users_updated_at
    before update on public.users
    for each row
    execute function public.handle_updated_at();

create trigger handle_reports_updated_at
    before update on public.reports
    for each row
    execute function public.handle_updated_at();
