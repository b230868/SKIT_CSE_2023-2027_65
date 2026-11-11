import { Router } from "express";
import { ReportsController } from "../controllers/reports.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

// Staff authentication and authorization required
router.use(authenticate);
router.use(requireRole(["faculty_mentor", "tp_officer", "admin"]));

// Faculty department and monitoring reports
router.get("/faculty", ReportsController.getFacultyReport);

// T&P college-wide placement and training statistics
router.get("/tp", ReportsController.getTpReport);

// Export report in JSON or CSV
router.get("/export", ReportsController.exportReport);

export default router;

