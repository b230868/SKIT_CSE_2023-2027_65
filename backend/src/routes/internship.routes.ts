import { Router } from "express";
import { InternshipController } from "../controllers/internship.controller";
import { authenticate } from "../middleware/auth";

const router = Router();

// All internship routes require authentication to ensure data scoping and privacy
router.use(authenticate);

// List internships (scoped by user role)
router.get("/", InternshipController.getAll);

// Create a new internship application/record
router.post("/", InternshipController.create);

// Get single internship by UUID
router.get("/:id", InternshipController.getById);

// Update internship details
router.patch("/:id", InternshipController.update);

// Progress updates
router.get("/:id/progress", InternshipController.getProgress);
router.post("/:id/progress", InternshipController.addProgress);

export default router;
