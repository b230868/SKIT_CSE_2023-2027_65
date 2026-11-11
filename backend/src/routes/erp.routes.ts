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

// Staff authentication required (restricted to T&P Officer and Admin)
router.use(authenticate);
router.use(requireRole(["tp_officer", "admin"]));

// ERP connectivity and sync status
router.get("/status", ErpController.getStatus);

// Export training records formatted for ERP database ingestion
router.get("/export", ErpController.exportToErp);

// Configure ERP database parameters
router.post("/configure-db", ErpController.configureDatabase);

// Trigger synchronization of records into ERP
router.post("/sync-records", ErpController.syncRecords);


export default router;

