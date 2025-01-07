import { serve } from "https://deno.land/std@0.204.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

// Type definitions for better type safety
type EmailLog = {
  id: string;
  user_id: string;
  email_type: 'report_reminder';
  status: 'pending' | 'success' | 'failed';
  metadata: {
    email: string;
    username: string;
    last_report_time?: string;
  };
  error_message?: string;
}

type ProcessingResult = {
  id: string;
  status: 'success' | 'failed';
  error?: string;
}

// Environment variable validation
const requiredEnvVars = {
  SUPABASE_URL: Deno.env.get('URL_SUPABASE'),
  SUPABASE_SERVICE_ROLE_KEY: Deno.env.get('SERVICE_ROLE_KEY_SUPABASE'),
  MAILING_TOKEN: Deno.env.get('MAILING_TOKEN'),
};

// Validate all required environment variables are present
Object.entries(requiredEnvVars).forEach(([name, value]) => {
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
});

// Email template function for consistent formatting
function generateEmailContent(username: string, lastReportTime?: string): string {
  const greeting = `Hello ${username}`;
  const lastReportMessage = lastReportTime 
    ? `Your last report was submitted on ${new Date(lastReportTime).toLocaleString()}.`
    : "We haven't received any reports from you yet.";

  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h1 style="color: #333;">${greeting}</h1>
      <p>We noticed you haven't submitted a report recently.</p>
      <p>${lastReportMessage}</p>
      <p>Please take a moment to submit your report. Regular reporting helps us provide better support.</p>
      <div style="margin-top: 20px; padding: 15px; background-color: #f8f9fa; border-radius: 5px;">
        <p style="margin: 0;">If you need any assistance, please don't hesitate to reach out to our support team.</p>
      </div>
    </div>
  `;
}

// Main processing function
async function processEmailLog(
  supabase: any, 
  email: EmailLog
): Promise<ProcessingResult> {
  try {
    // Send email
    // const response = await fetch('https://send.api.mailtrap.io/api/send', {
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${requiredEnvVars.MAILING_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: { 
          email: 'noreply@spearcad.com', 
          name: 'Spearcad' 
        },
        to: [{ 
          email: email.metadata.email 
        }],
        subject: 'Report Reminder - Spearcad',
        html: generateEmailContent(
          email.metadata.username,
          email.metadata.last_report_time
        )
      })
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(`MAILING API error: ${JSON.stringify(errorData)}`);
    }

    // Update email status to success
    const { error: updateError } = await supabase
      .from('email_logs')
      .update({ 
        status: 'success',
        updated_at: new Date().toISOString()
      })
      .eq('id', email.id);

    if (updateError) throw updateError;

    return { 
      id: email.id, 
      status: 'success' 
    };

  } catch (error) {
    // Log the error and update the email status
    console.error(`Error processing email ${email.id}:`, error);

    await supabase
      .from('email_logs')
      .update({ 
        status: 'failed',
        error_message: error.message,
        updated_at: new Date().toISOString()
      })
      .eq('id', email.id);

    return { 
      id: email.id, 
      status: 'failed', 
      error: error.message 
    };
  }
}

// Main serve function
serve(async (req: Request) => {
  // Initialize Supabase client
  const supabase = createClient(
    requiredEnvVars.SUPABASE_URL,
    requiredEnvVars.SUPABASE_SERVICE_ROLE_KEY
  );

  try {
    // Get pending emails
    const { data: pendingEmails, error: queryError } = await supabase
      .from('email_logs')
      .select('*')
      .eq('status', 'pending')
      .eq('email_type', 'report_reminder')
      .order('created_at', { ascending: true })
      .limit(50) as { data: EmailLog[], error: any };

    if (queryError) throw queryError;

    if (!pendingEmails || pendingEmails.length === 0) {
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No pending emails to process' 
        }),
        { headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Process emails in parallel with rate limiting
    const results = await Promise.all(
      pendingEmails.map((email, index) => 
        // Add slight delay between requests to prevent rate limiting
        new Promise(resolve => 
          setTimeout(
            () => resolve(processEmailLog(supabase, email)), 
            index * 200
          )
        )
      )
    );

    // Compile statistics
    const stats = results.reduce((acc: any, result: ProcessingResult) => {
      acc[result.status] = (acc[result.status] || 0) + 1;
      return acc;
    }, {});

    return new Response(
      JSON.stringify({
        success: true,
        processed: results.length,
        stats,
        results
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Function error:', error);

    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500, 
        headers: { 'Content-Type': 'application/json' } 
      }
    );
  }
});