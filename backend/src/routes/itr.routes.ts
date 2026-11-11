import { Router } from "express";
import { ItrController } from "../controllers/itr.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

router.use(authenticate);

router.get("/", ItrController.getAll);
router.get("/:id", ItrController.getById);
router.patch(
  "/:id/review",
  requireRole(["industry_supervisor", "faculty_mentor", "tp_officer", "admin"]),
  ItrController.review
);

export default router;

