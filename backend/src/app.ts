import express from "express";
import cors from "cors";
import { prisma } from "./config/db";
import { requestLogger } from "./middleware/logger";
import { errorHandler, notFoundHandler } from "./middleware/errorHandler";
import { authenticate, requireRole } from "./middleware/auth";
import studentRoutes from "./routes/student.routes";
import internshipRoutes from "./routes/internship.routes";
import monitoringRoutes from "./routes/monitoring.routes";
import authRoutes from "./routes/auth.routes";
import { sendSuccess } from "./utils/response";

const app = express();

// Standard middleware
app.use(cors());
app.use(express.json());
app.use(requestLogger);

// Public status check endpoint (safe non-sensitive message)
app.get("/", (_req, res) => {
  res.json({
    message: "Prashikshan backend is running!",
    version: "1.0.0",
    status: "healthy",
  });
});

// Protected database connectivity test endpoint (restricted to authorized staff)
app.get(
  "/db-test",
  authenticate,
  requireRole(["faculty_mentor", "tp_officer", "admin"]),
  async (_req, res, next) => {
    try {
      const result = await prisma.$queryRaw<
        { database_name: string }[]
      >`SELECT current_database() AS database_name`;

      res.json({
        success: true,
        message: "Supabase connection successful!",
        database: result[0]?.database_name,
      });
    } catch (error) {
      next(error);
    }
  }
);

// Safe public health ping (no sensitive database internal names or credentials exposed)
app.get("/health", async (_req, res, next) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return sendSuccess(res, {
      status: "ok",
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    next(error);
  }
});

// Feature routers
app.use("/students", studentRoutes);
app.use("/internships", internshipRoutes);
app.use("/monitoring", monitoringRoutes);
app.use("/auth", authRoutes);

// 404 handler for unknown routes
app.use(notFoundHandler);

// Centralized error handler
app.use(errorHandler);

export default app;
