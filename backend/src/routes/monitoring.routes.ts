import { Router } from "express";
import { MonitoringController } from "../controllers/monitoring.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

// Protected monitoring endpoints for staff
router.use(authenticate);
router.use(requireRole(["faculty_mentor", "tp_officer", "admin"]));

// Student monitoring list
router.get("/students", MonitoringController.getStudents);

export default router;
