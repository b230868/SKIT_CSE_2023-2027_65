import { Router } from "express";
import { MonitoringController } from "../controllers/monitoring.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

// Protected monitoring endpoints for staff (Faculty Mentors, T&P Officers, Admins)
router.use(authenticate);
router.use(requireRole(["faculty_mentor", "tp_officer", "admin"]));

// Monitoring dashboard aggregated metrics
router.get("/dashboard", MonitoringController.getDashboardStats);

// Student monitoring list
router.get("/students", MonitoringController.getStudents);

// Specific student monitoring detail
router.get("/students/:id", MonitoringController.getStudentDetails);

// Document verification endpoint
router.patch("/documents/:id", MonitoringController.verifyDocument);

export default router;
