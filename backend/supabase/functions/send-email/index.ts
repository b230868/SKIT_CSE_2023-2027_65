// Supabase Edge Function: Send Email Hook
// Deployed with: supabase functions deploy send-email --no-verify-jwt
// Documentation: https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook
// Official example: https://supabase.com/docs/guides/functions/examples/auth-send-email-hook-react-email-resend

import { Webhook } from "npm:standardwebhooks@^1.0.0";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") || "";
const SEND_EMAIL_HOOK_SECRET = (
  Deno.env.get("SEND_EMAIL_HOOK_SECRET") || ""
).replace("v1,whsec_", "");
const FROM_EMAIL = Deno.env.get("EMAIL_FROM") || "Prashikshan <onboarding@resend.dev>";

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: { http_code: 405, message: "Method Not Allowed" } }),
      { status: 405, headers: { "Content-Type": "application/json" } }
    );
  }

  try {
    const payload = await req.text();
    const headers = Object.fromEntries(req.headers);

    let eventData: any;
    if (SEND_EMAIL_HOOK_SECRET) {
      const wh = new Webhook(SEND_EMAIL_HOOK_SECRET);
      eventData = wh.verify(payload, headers);
    } else {
      eventData = JSON.parse(payload);
    }

    const { user, email_data } = eventData || {};
    const recipient = user?.email;
    const actionType = email_data?.email_action_type || "notification";
    const token = email_data?.token || "";
    const siteUrl = (email_data?.site_url || "http://localhost:3000").replace(/\/$/, "");
    const redirectTo = encodeURIComponent(email_data?.redirect_to || siteUrl);
    const actionUrl = `${siteUrl}/auth/v1/verify?token=${encodeURIComponent(
      email_data?.token_hash || ""
    )}&type=${encodeURIComponent(actionType)}&redirect_to=${redirectTo}`;

    if (!recipient) {
      return new Response(
        JSON.stringify({
          error: {
            http_code: 400,
            message: "Invalid payload: recipient email is missing",
          },
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Fail explicitly if no email delivery provider is configured.
    // Prevent false success reporting to Supabase Auth.
    if (!RESEND_API_KEY) {
      return new Response(
        JSON.stringify({
          error: {
            http_code: 503,
            message: "Email delivery service unavailable: RESEND_API_KEY is not configured",
          },
        }),
        { status: 503, headers: { "Content-Type": "application/json" } }
      );
    }

    let subject = "Prashikshan Notification";
    if (actionType === "signup") subject = "Confirm Your Prashikshan Account";
    else if (actionType === "recovery") subject = "Reset Your Prashikshan Password";
    else if (actionType === "invite") subject = "Invitation to Prashikshan";
    else if (actionType === "magiclink") subject = "Your Prashikshan Sign-In Link";

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [recipient],
        subject,
        html: `<p>Hello,</p><p>Action: <strong>${subject}</strong></p>${
          token ? `<p>Verification code: <strong>${token}</strong></p>` : ""
        }<p><a href="${actionUrl}">Click here to proceed</a></p>`,
      }),
    });

    if (!res.ok) {
      const errorText = await res.text();
      return new Response(
        JSON.stringify({
          error: {
            http_code: 422,
            message: `Email provider delivery rejected: ${errorText}`,
          },
        }),
        { status: 422, headers: { "Content-Type": "application/json" } }
      );
    }

    // Return empty 200 JSON object strictly upon successful delivery per Supabase protocol
    return new Response(JSON.stringify({}), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({
        error: {
          http_code: 400,
          message: `Hook processing error: ${err.message}`,
        },
      }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }
});
