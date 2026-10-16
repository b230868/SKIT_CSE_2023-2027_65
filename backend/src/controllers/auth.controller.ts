import { Request, Response, NextFunction } from "express";
import crypto from "crypto";
import { sendSuccess } from "../utils/response";

export interface SupabaseEmailHookPayload {
  user: {
    id: string;
    aud?: string;
    role?: string;
    email: string;
    phone?: string;
    user_metadata?: Record<string, any>;
    app_metadata?: Record<string, any>;
  };
  email_data: {
    token: string;
    token_hash: string;
    redirect_to: string;
    email_action_type:
      | "signup"
      | "invite"
      | "magiclink"
      | "recovery"
      | "email_change"
      | "email"
      | "reauthentication"
      | string;
    site_url: string;
    token_new?: string;
    token_hash_new?: string;
  };
}

export class AuthController {
  /**
   * POST /auth/send-email-hook
   * Official Supabase Auth Send Email Hook endpoint.
   * Intercepts Supabase Auth email events (signup, password recovery, invite, magic link)
   * and delivers them through Resend or transactional mailer API, bypassing Supabase's
   * built-in 2-4 emails/hour rate limit.
   */
  static async handleSendEmailHook(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<any> {
    try {
      const payload = req.body as SupabaseEmailHookPayload;

      // 1. Validate payload structure per Supabase Auth Hook specifications
      if (!payload || !payload.user || !payload.email_data) {
        return res.status(400).json({
          error: {
            http_code: 400,
            message: "Invalid Send Email Hook payload: missing user or email_data",
          },
        });
      }

      const { user, email_data } = payload;
      const recipientEmail = user.email;
      const actionType = email_data.email_action_type;

      if (!recipientEmail) {
        return res.status(400).json({
          error: {
            http_code: 400,
            message: "Recipient email address is missing from user payload",
          },
        });
      }

      // 2. Verify Hook Secret if configured in environment
      const hookSecret = process.env.SEND_EMAIL_HOOK_SECRET;
      if (hookSecret) {
        const isValid = AuthController.verifyHookSignature(
          JSON.stringify(payload),
          req.headers,
          hookSecret
        );

        if (!isValid) {
          console.warn("[SendEmailHook] Unauthorized: Invalid or missing webhook signature/secret");
          return res.status(401).json({
            error: {
              http_code: 401,
              message: "Unauthorized: Invalid or missing webhook signature or authorization secret",
            },
          });
        }
      }

      // 3. Construct Verification / Recovery URL and content
      const siteUrl = (email_data.site_url || "http://localhost:3000").replace(/\/$/, "");
      const redirectTo = encodeURIComponent(email_data.redirect_to || siteUrl);
      const actionUrl = `${siteUrl}/auth/v1/verify?token=${encodeURIComponent(
        email_data.token_hash
      )}&type=${encodeURIComponent(actionType)}&redirect_to=${redirectTo}`;

      const { subject, htmlContent, textContent } = AuthController.buildEmailContent(
        actionType,
        email_data.token,
        actionUrl,
        user.user_metadata?.full_name || "Prashikshan User"
      );

      // 4. Dispatch Email via Resend API or Fail Gracefully (No False Success)
      const resendApiKey = process.env.RESEND_API_KEY;
      const fromEmail =
        process.env.EMAIL_FROM || "Prashikshan Portal <onboarding@resend.dev>";

      if (resendApiKey) {
        const response = await fetch("https://api.resend.com/emails", {
          method: "POST",
          headers: {
            Authorization: `Bearer ${resendApiKey}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            from: fromEmail,
            to: [recipientEmail],
            subject,
            html: htmlContent,
            text: textContent,
          }),
        });

        if (!response.ok) {
          const errorBody = await response.text();
          console.error("[SendEmailHook] External email provider rejected delivery request.");
          return res.status(422).json({
            error: {
              http_code: 422,
              message: `Email provider error: ${response.statusText}`,
            },
          });
        }

        console.log(`[SendEmailHook] Dispatched '${actionType}' email via Resend.`);
      } else if (process.env.ALLOW_TEST_SIMULATED_DISPATCH === "true") {
        // Isolated automated testing harness ONLY. Sensitive data is NEVER logged.
        console.log(`[SendEmailHook:Test] Processed simulated test dispatch for '${actionType}'.`);
      } else {
        // No provider configured: fail explicitly to prevent false success reporting to Supabase Auth
        console.error(
          "[SendEmailHook] Delivery aborted: No transactional email provider configured (RESEND_API_KEY missing)."
        );
        return res.status(503).json({
          error: {
            http_code: 503,
            message: "Email delivery service unavailable: Provider API key is not configured.",
          },
        });
      }

      // 5. Respond according to Supabase Send Email Hook protocol (Empty 200 JSON object)
      return res.status(200).json({});
    } catch (error: any) {
      console.error("[SendEmailHook] Unhandled error during email dispatch.");
      return res.status(500).json({
        error: {
          http_code: 500,
          message: error.message || "Internal server error during email dispatch",
        },
      });
    }
  }

  /**
   * Helper to verify Standard Webhooks or Bearer secret authorization
   */
  static verifyHookSignature(
    rawBody: string,
    headers: Record<string, any>,
    secret: string
  ): boolean {
    const cleanSecret = secret.replace(/^v1,whsec_/, "").replace(/^whsec_/, "").trim();

    // 1. Direct Bearer token check
    const authHeader = (headers["authorization"] as string) || "";
    if (authHeader && authHeader.replace(/^Bearer\s+/i, "").trim() === cleanSecret) {
      return true;
    }

    // 2. Standard Webhook signature verification (svix / StandardWebhooks)
    const webhookId = (headers["webhook-id"] || headers["x-webhook-id"]) as string;
    const webhookTimestamp = (headers["webhook-timestamp"] || headers["x-webhook-timestamp"]) as string;
    const webhookSignature = (headers["webhook-signature"] || headers["x-webhook-signature"] || headers["x-supabase-signature"]) as string;

    if (!webhookId || !webhookTimestamp || !webhookSignature) {
      return false;
    }

    const now = Math.floor(Date.now() / 1000);
    const ts = parseInt(webhookTimestamp, 10);
    if (isNaN(ts) || Math.abs(now - ts) > 300) {
      // Reject if timestamp differs by more than 5 minutes
      return false;
    }

    let secretBytes: Buffer;
    try {
      secretBytes = Buffer.from(cleanSecret, "base64");
    } catch {
      secretBytes = Buffer.from(cleanSecret, "utf8");
    }

    const signedContent = `${webhookId}.${webhookTimestamp}.${rawBody}`;
    const expectedHmac = crypto.createHmac("sha256", secretBytes).update(signedContent).digest("base64");

    const sigParts = webhookSignature.split(" ");
    for (const part of sigParts) {
      const [version, sig] = part.split(",");
      if (version === "v1" && sig === expectedHmac) {
        return true;
      }
    }

    return false;
  }

  /**
   * GET /auth/email-hook-status
   * Diagnostic endpoint to verify email delivery architecture configuration.
   */
  static async getEmailDeliveryStatus(_req: Request, res: Response): Promise<any> {
    const hasResend = Boolean(process.env.RESEND_API_KEY);
    const hasHookSecret = Boolean(process.env.SEND_EMAIL_HOOK_SECRET);
    const fromEmail = process.env.EMAIL_FROM || "Default (onboarding@resend.dev)";

    return sendSuccess(res, {
      provider: hasResend ? "Resend API" : "Unconfigured (RESEND_API_KEY missing)",
      deliveryStatus: hasResend ? "READY" : "BLOCKED_PENDING_PROVIDER_KEY",
      hookSecretConfigured: hasHookSecret,
      fromEmail,
      supportedActions: ["signup", "recovery", "invite", "magiclink", "email_change"],
      documentation: "https://supabase.com/docs/guides/auth/auth-hooks/send-email-hook",
      rateLimitLayers: {
        builtInSupabaseQuota: "2-4 emails/hr (Bypassed when Custom SMTP or Send Email Hook is active in Supabase)",
        supabaseAuthEndpointLimits: "Default 30 requests/hr per IP; 60s per-user OTP/recovery interval",
        customProviderQuota: "Governed by external provider (e.g. Resend free plan: 3,000/month, max 100/day)",
        applicationInFlightGuard: "In-flight mutex (_isEmailActionInProgress) prevents concurrent double-clicks without static delay",
      },
    });
  }

  private static buildEmailContent(
    actionType: string,
    token: string,
    actionUrl: string,
    userName: string
  ): { subject: string; htmlContent: string; textContent: string } {
    let subject = "Prashikshan Notification";
    let actionTitle = "Prashikshan Portal";
    let actionDescription = "Please follow the instructions below:";

    if (actionType === "signup") {
      subject = "Confirm Your Prashikshan Account";
      actionTitle = "Welcome to Prashikshan!";
      actionDescription =
        "Thank you for registering. Please confirm your email address using the 6-digit code or the verification link below:";
    } else if (actionType === "recovery") {
      subject = "Reset Your Prashikshan Password";
      actionTitle = "Password Recovery Request";
      actionDescription =
        "We received a request to reset your password. Use the 6-digit code or click the button below to choose a new password:";
    } else if (actionType === "invite") {
      subject = "You have been invited to Prashikshan";
      actionTitle = "Join Prashikshan Internship Portal";
      actionDescription =
        "You have been invited to access the Prashikshan portal. Complete your registration below:";
    } else if (actionType === "magiclink") {
      subject = "Your Prashikshan Magic Sign-In Link";
      actionTitle = "Sign in to Prashikshan";
      actionDescription =
        "Use the link below to securely sign in without a password:";
    }

    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f4f5f7; margin: 0; padding: 24px; color: #172b4d; }
          .container { max-width: 580px; margin: 0 auto; background: #ffffff; border-radius: 8px; padding: 32px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
          .header { text-align: center; border-bottom: 2px solid #6366f1; padding-bottom: 16px; margin-bottom: 24px; }
          .title { font-size: 22px; font-weight: 700; color: #1e1b4b; margin: 0 0 8px 0; }
          .otp-box { background: #eef2ff; border: 1px dashed #6366f1; border-radius: 6px; padding: 16px; text-align: center; margin: 24px 0; font-size: 28px; font-weight: 800; letter-spacing: 6px; color: #4338ca; }
          .btn-container { text-align: center; margin: 28px 0; }
          .button { display: inline-block; background-color: #4f46e5; color: #ffffff !important; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: 600; }
          .footer { font-size: 12px; color: #6b7280; text-align: center; margin-top: 32px; border-top: 1px solid #e5e7eb; padding-top: 16px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1 class="title">Prashikshan</h1>
            <p style="margin: 0; color: #6b7280; font-size: 14px;">Internship & Training Management Portal</p>
          </div>
          <p>Hello <strong>${userName}</strong>,</p>
          <p>${actionDescription}</p>
          ${token ? `<div class="otp-box">${token}</div>` : ""}
          <div class="btn-container">
            <a href="${actionUrl}" class="button" target="_blank">Proceed to Prashikshan</a>
          </div>
          <p style="font-size: 13px; color: #6b7280;">If the button does not work, copy and paste this link into your browser:<br><a href="${actionUrl}" style="color: #4f46e5; word-break: break-all;">${actionUrl}</a></p>
          <div class="footer">
            <p>&copy; ${new Date().getFullYear()} Prashikshan. If you did not request this email, you can safely ignore it.</p>
          </div>
        </div>
      </body>
      </html>
    `;

    const textContent = `
${actionTitle}
Hello ${userName},

${actionDescription}

${token ? `Your Verification Code: ${token}\n` : ""}
Direct Link: ${actionUrl}

If you did not request this email, please ignore it.
Prashikshan Internship & Training Portal
    `.trim();

    return { subject, htmlContent, textContent };
  }
}
