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

router.get(
  "/analytics",
  requireRole(["industry_supervisor", "faculty_mentor", "tp_officer", "admin"]),
  IndustryController.getAnalytics
);

export default router;

