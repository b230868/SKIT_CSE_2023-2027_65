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

router.post(
  "/auto-sync",
  authenticate,
  requireRole(["tp_officer", "admin"]),
  ErpController.autoSync
);

router.get(
  "/sync-history",
  authenticate,
  requireRole(["tp_officer", "admin"]),
  ErpController.getSyncHistory
);

export default router;

