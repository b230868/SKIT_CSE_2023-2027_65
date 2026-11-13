import { Router } from "express";
import { ReportsController } from "../controllers/reports.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

// Staff and Industry authentication required
router.use(authenticate);

// Faculty department and monitoring reports
router.get(
  "/faculty",
  requireRole(["faculty_mentor", "tp_officer", "admin"]),
  ReportsController.getFacultyReport
);

// T&P college-wide placement and training statistics
router.get(
  "/tp",
  requireRole(["tp_officer", "admin"]),
  ReportsController.getTpReport
);

// Export report in JSON, CSV, or XLSX format
router.get(
  "/export",
  requireRole(["faculty_mentor", "tp_officer", "industry_supervisor", "admin"]),
  ReportsController.exportReport
);

export default router;

