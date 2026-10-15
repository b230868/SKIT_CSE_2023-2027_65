import { Router } from "express";
import { AuthController } from "../controllers/auth.controller";

const router = Router();

/**
 * POST /auth/send-email-hook
 * Official Supabase Auth Send Email Hook.
 * Called by Supabase Auth service when sending verification, confirmation, or recovery emails.
 * Protocol: responds with 200 and empty JSON `{}` on success per Supabase Auth Hook specs.
 */
router.post("/send-email-hook", AuthController.handleSendEmailHook);

/**
 * GET /auth/email-hook-status
 * Health & diagnostic check for email delivery service configuration.
 */
router.get("/email-hook-status", AuthController.getEmailDeliveryStatus);

export default router;
