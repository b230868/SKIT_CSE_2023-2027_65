import { Router } from "express";
import { IndustryController } from "../controllers/industry.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

// Protect all industry routes
router.use(authenticate);

// Industry Supervisor, Faculty, and Admin can view dashboard and interns
router.get(
  "/dashboard",
  requireRole(["industry_supervisor", "faculty_mentor", "tp_officer", "admin"]),
  IndustryController.getDashboard
);

router.get(
  "/interns",
  requireRole(["industry_supervisor", "faculty_mentor", "tp_officer", "admin"]),
  IndustryController.getInterns
);

router.post(
  "/evaluations",
  requireRole(["industry_supervisor", "admin"]),
  IndustryController.submitEvaluation
);

// Evaluation history / audit trail
router.get(
  "/evaluations/:internshipId/history",
  requireRole(["industry_supervisor", "faculty_mentor", "tp_officer", "admin"]),
  IndustryController.getEvaluationHistory
);

// Batch attendance marking
router.post(
  "/attendance/batch",
  requireRole(["industry_supervisor", "admin"]),
  IndustryController.submitBatchAttendance
);

// Company affiliation requests
router.post(
  "/affiliation/request",
  requireRole(["industry_supervisor"]),
  IndustryController.submitAffiliationRequest
);

router.get(
  "/affiliation/requests",
  requireRole(["industry_supervisor", "tp_officer", "admin"]),
  IndustryController.getAffiliationRequests
);

router.patch(
  "/affiliation/requests/:id",
  requireRole(["tp_officer", "admin"]),
  IndustryController.reviewAffiliationRequest
);

router.get(
  "/analytics",
  requireRole(["industry_supervisor", "faculty_mentor", "tp_officer", "admin"]),
  IndustryController.getAnalytics
);

export default router;

