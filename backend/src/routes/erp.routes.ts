import { Router } from "express";
import { ErpController } from "../controllers/erp.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

// ERP health & deployment status
router.get("/status", ErpController.getStatus);

// Secure ERP data sync endpoints (accessible by T&P Officers, Admins)
router.get(
  "/export",
  authenticate,
  requireRole(["tp_officer", "admin"]),
  ErpController.getExportData
);

router.post(
  "/sync-grades",
  authenticate,
  requireRole(["tp_officer", "admin"]),
  ErpController.syncGrades
);

export default router;

