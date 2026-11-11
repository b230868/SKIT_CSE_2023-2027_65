import { Router } from "express";
import { ApprovalController } from "../controllers/approval.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

// Require authentication for all approval routes
router.use(authenticate);

// Approvals summary statistics
router.get(
  "/stats/summary",
  requireRole(["faculty_mentor", "tp_officer", "admin"]),
  ApprovalController.getStats
);

// List approvals with filters
router.get(
  "/",
  requireRole(["faculty_mentor", "tp_officer", "admin"]),
  ApprovalController.getAll
);

// Get approval by review ID
router.get(
  "/:id",
  requireRole(["faculty_mentor", "tp_officer", "admin"]),
  ApprovalController.getById
);

// Submit review for an internship
router.post(
  "/:internshipId/review",
  requireRole(["faculty_mentor", "tp_officer", "admin"]),
  ApprovalController.createReview
);

export default router;

