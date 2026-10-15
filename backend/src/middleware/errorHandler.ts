import { Request, Response, NextFunction } from "express";
import { ZodError } from "zod";
import { ApiError, sendError } from "../utils/response";

export function notFoundHandler(req: Request, res: Response) {
  sendError(res, `Route not found: ${req.method} ${req.originalUrl}`, 404);
}

export function errorHandler(
  err: any,
  _req: Request,
  res: Response,
  _next: NextFunction
) {
  // 1. Handled ApiError
  if (err instanceof ApiError) {
    return sendError(res, err.message, err.statusCode, err.details);
  }

  // 2. Zod validation error
  if (err instanceof ZodError) {
    const formattedErrors = err.issues.map((issue) => ({
      path: issue.path.join("."),
      message: issue.message,
    }));
    return sendError(res, "Request validation failed", 400, formattedErrors);
  }

  // 3. Prisma Client known errors
  if (err?.code && typeof err.code === "string" && err.code.startsWith("P")) {
    switch (err.code) {
      case "P2025":
        return sendError(res, "Record not found", 404);
      case "P2002": {
        const target = err.meta?.target ? ` (${(err.meta.target as any[]).join(", ")})` : "";
        return sendError(res, `Unique constraint violation${target}`, 409);
      }
      case "P2003":
        return sendError(res, "Foreign key constraint failed: related record not found", 400);
      case "P2023":
        return sendError(res, "Inconsistent column data or invalid UUID format", 400);
      default:
        console.error("Prisma database error:", err.code, err.message);
        return sendError(res, "Database query error", 500);
    }
  }

  // 4. JSON body parsing error
  if (err instanceof SyntaxError && "body" in err) {
    return sendError(res, "Malformed JSON in request body", 400);
  }

  // 5. Unexpected server errors
  console.error("Unhandled error:", err);
  const message =
    process.env.NODE_ENV === "development"
      ? err.message || "Internal server error"
      : "Internal server error";

  return sendError(res, message, 500);
}
