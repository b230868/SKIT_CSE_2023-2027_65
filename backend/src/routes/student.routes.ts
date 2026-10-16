import { Router } from "express";
import { StudentController } from "../controllers/student.controller";
import { authenticate, requireRole } from "../middleware/auth";

const router = Router();

// All student routes require authentication to protect sensitive student records
router.use(authenticate);

// Retrieve all students (restricted to Faculty Mentors, T&P Officers, and Admins)
router.get(
  "/",
  requireRole(["faculty_mentor", "tp_officer", "admin"]),
  StudentController.getAll
);

// Retrieve profile of the currently logged-in student (MUST come before /:id)
router.get("/me", StudentController.getMe);

// Retrieve a single student by UUID (Student can view own; Staff can view any)
router.get("/:id", StudentController.getById);

// Update a student record (enforces ownership in controller)
router.patch("/:id", StudentController.update);

export default router;
