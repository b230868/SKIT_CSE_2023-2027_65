import { Router } from "express";
import { PlacementController } from "../controllers/placement.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

router.use(authenticate);

// Branch discovery & T&P summary
router.get("/branches", PlacementController.getAvailableBranches);
router.get(
  "/summary",
  requireRole(["tp_officer", "admin", "faculty_mentor"]),
  PlacementController.getDashboardSummary
);

// Placement & internship notices
router.get("/notices", PlacementController.getNotices);
router.get("/notices/:id", PlacementController.getNoticeById);
router.post(
  "/notices",
  requireRole(["tp_officer", "admin"]),
  PlacementController.createNotice
);
router.patch(
  "/notices/:id",
  requireRole(["tp_officer", "admin"]),
  PlacementController.updateNotice
);
router.delete(
  "/notices/:id",
  requireRole(["tp_officer", "admin"]),
  PlacementController.deleteNotice
);
router.post("/notices/:id/read", PlacementController.markNoticeRead);

// FAQs & Smart FAQ suggestions
router.get("/faqs", PlacementController.getFaqs);
router.get("/faqs/suggest", PlacementController.suggestFaqs);
router.post(
  "/faqs",
  requireRole(["tp_officer", "admin"]),
  PlacementController.createFaq
);
router.patch(
  "/faqs/:id",
  requireRole(["tp_officer", "admin"]),
  PlacementController.updateFaq
);
router.delete(
  "/faqs/:id",
  requireRole(["tp_officer", "admin"]),
  PlacementController.deleteFaq
);

// Student queries & replies
router.get("/queries", PlacementController.getQueries);
router.post("/queries", PlacementController.createQuery);
router.post("/queries/:id/replies", PlacementController.addQueryReply);
router.patch(
  "/queries/:id/status",
  requireRole(["tp_officer", "admin"]),
  PlacementController.updateQueryStatus
);

// NOC requests
router.get("/noc-requests", PlacementController.getNocRequests);
router.post("/noc-requests", PlacementController.createNocRequest);
router.patch(
  "/noc-requests/:id/review",
  requireRole(["tp_officer", "admin"]),
  PlacementController.reviewNocRequest
);

export default router;
