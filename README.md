# Supabase Edge Functions Email System

This project implements an automated email reminder system using Supabase Edge Functions, PostgreSQL, and email service providers (SendGrid/Mailtrap). The system identifies inactive users and sends reminder emails through a scheduled cron job.

## System Overview

1. PostgreSQL functions identify inactive users
2. Cron jobs queue reminder emails
3. Edge Functions process the queue and send emails
4. Email logs track the status of all communications

## Prerequisites

- Docker Desktop (for local development)
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- [Supabase Account](https://supabase.com)
- Email Service Provider Account (SendGrid or Mailtrap)
- Node.js v16+ and npm

### Installing Prerequisites

```bash
# Install Docker (Linux)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
# For macOS/Windows: Download from https://www.docker.com/products/docker-desktop

# Install Supabase CLI
npm install -g supabase
# Or using Brew
brew install supabase/tap/supabase

# Install Node.js using nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 16
nvm use 16
```

## Project Setup

### 1. Initial Setup

```bash
# Create and initialize project
mkdir email-reminder-system
cd email-reminder-system
supabase init

# Set up environment files
cp .env.example .env
```

Configure your `.env` file:

```env
PUBLIC_SUPABASE_URL=http://localhost:54321
PUBLIC_SUPABASE_ANON_KEY=<your-local-anon-key>
PUBLIC_SUPABASE_SERVICE_ROLE_KEY=<your-local-service-role-key>
MAILING_TOKEN=<your-sendgrid-or-mailtrap-key>
```

### 2. Supabase Project Configuration

1. Create a new project at [dashboard.supabase.com](https://dashboard.supabase.com)
2. Navigate to Settings -> API and note:
   - Project URL
   - Project API Keys (anon and service_role)
3. Add environment variables under Settings -> Edge Functions:
   ```bash
   URL_SUPABASE=your_project_url
   SERVICE_ROLE_KEY_SUPABASE=your_service_role_key
   MAILING_TOKEN=your_email_provider_api_key
   ```

### 2.1 Environment Variables for Edge Functions

To make environment variables accessible to your Deno Edge Functions:

1. **Local Development:**

   ```bash
   # Add variables to .env file
   echo "MY_SECRET_KEY=value" >> .env

   # Run function with env file
   supabase functions serve --env-file .env
   ```

2. **Production Environment:**

   ```bash
   # Set single secret
   supabase secrets set MY_SECRET_KEY=value

   # Set multiple secrets from .env file
   supabase secrets set --env-file .env

   # List current secrets
   supabase secrets list
   ```

   ```bash
   # Manual Configuration via Supabase Dashboard

   # 1. Navigate to your project\'s Edge Functions settings
   # https://supabase.com/dashboard/project/<YOUR_PROJECT_ID>/settings/functions

   # 2. Add the following required secrets:
   supabase secrets set URL_SUPABASE="your_project_url"
   supabase secrets set SERVICE_ROLE_KEY_SUPABASE="your_service_role_key"
   supabase secrets set MAILING_TOKEN="your_email_provider_api_key"
   supabase secrets set FROM_EMAIL="no-reply@yourdomain.com"
   supabase secrets set FROM_NAME="Your App Name"

   # 3. Verify secrets are set
   supabase secrets list

   # Note: Changes take effect immediately for deployed Edge Functions
   # No restart or redeployment needed
   ```

3. **Accessing Variables in Edge Functions:**
   ```typescript
   // Access in your Edge Function
   const mySecret = Deno.env.get("MY_SECRET_KEY");
   ```

Note: Secrets set via the Supabase CLI are automatically available in both local development (when using `--env-file`) and in production deployments.

### 3. Database Setup

```bash
# Start Supabase locally
supabase start

# Generate TypeScript types
supabase gen types typescript --project-id <project-id> > types/db-schema.ts

# Create and run migrations
mkdir -p migrations
supabase migration new create_initial_schema
supabase migration new create_identify_inactive_users
supabase migration new create_queue_reminder_emails
supabase migration new setup_cron_job
supabase migration up
```

Enable pg_cron extension (requires Supabase Pro plan):

- Dashboard -> Database -> Extensions
- Search for "pg_cron" and enable it

### 4. Email Provider Configuration

#### SendGrid Setup

1. Create account at [SendGrid](https://signup.sendgrid.com)
2. Create API key with "Mail Send" permissions
3. Verify sender email in Settings -> Sender Authentication
4. Update provider in `functions/helloEmail/index.ts`:
   ```typescript
   const provider: EmailProvider = "sendgrid";
   ```

#### Mailtrap Setup

1. Create account at [Mailtrap](https://mailtrap.io/signup)
2. Get API token from Email Testing -> Inboxes -> SMTP Settings
3. Ensure provider in `functions/helloEmail/index.ts` is set to:
   ```typescript
   const provider: EmailProvider = "mailtrap";
   ```

Note: The system uses Mailtrap by default. If you want to use SendGrid instead, make sure to:

1. Change the provider setting as shown above
2. Update your `MAILING_TOKEN` environment variable with your SendGrid API key
3. Verify your sender email with SendGrid before sending emails

### 5. Edge Function Setup

```bash
# Create function directory
mkdir -p supabase/functions/helloEmail
touch supabase/functions/helloEmail/index.ts

# Deploy locally
supabase functions serve helloEmail --env-file .env

# Deploy to production
supabase functions deploy helloEmail
```

## Testing

### Local Testing

```bash
# Add test user
INSERT INTO public.users (email, username)
VALUES ('test@example.com', 'testuser');

# Test email queue
SELECT public.queue_reminder_emails();

# Trigger Edge Function
curl -X POST http://localhost:54321/functions/v1/helloEmail \
-H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}"
```

### Monitoring and Verification

```sql
-- Check email status
SELECT FROM check_email_reminder_status();

-- View scheduled jobs
SELECT FROM cron.job;

-- Check email logs
SELECT * FROM email_logs ORDER BY created_at DESC LIMIT 5;
```

## Troubleshooting Guide

### Database Issues

```bash
# Reset database
supabase db reset

# Restart services
supabase stop
supabase start
```

### Type Generation Issues

```bash
# Force regenerate types
supabase gen types typescript --project-id <project-id> --schema public > types/db-schema.ts
```

### Edge Function Errors

```bash
# Check logs
supabase functions logs
# Restart function
supabase functions serve helloEmail --no-verify-jwt
```

Common Issues:

- Email provider API key expiration
- Rate limit exceeded
- Unverified sender email
- Database connection problems

## Security Considerations

1. Environment variables are securely stored in Supabase
2. Service role key is used only in Edge Functions
3. Row Level Security (RLS) is enabled on all tables
4. Email logs track all attempts and errors

## Production Deployment

```bash
# Push database changes
supabase db push

# Deploy functions
supabase functions deploy helloEmail

# Set environment variables
supabase secrets set --env-file .env
```

## Additional Resources

- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [SendGrid API Documentation](https://docs.sendgrid.com/api-reference/mail-send/mail-send)
- [Mailtrap Documentation](https://mailtrap.io/docs/)
- [pg_cron Documentation](https://github.com/citusdata/pg_cron)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
