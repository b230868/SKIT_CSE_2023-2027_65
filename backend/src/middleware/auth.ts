import { Request, Response, NextFunction } from "express";
import { verifySupabaseToken } from "../config/supabase";
import { prisma } from "../config/db";
import { ApiError } from "../utils/response";

export type RoleType =
  | "student"
  | "faculty_mentor"
  | "tp_officer"
  | "industry_supervisor"
  | "admin";

export interface AuthUser {
  id: string; // Supabase auth.users UUID
  email?: string;
  role: RoleType;
  isActive: boolean;
  profileId: string;
  studentId?: string;
  facultyId?: string;
  department?: string | null;
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
    }
  }
}

/**
 * Middleware: Verifies the Supabase JWT token and resolves user identity & role from database.
 */
export async function authenticate(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      throw ApiError.unauthorized("Authentication token required. Use 'Bearer <token>'");
    }

    const token = authHeader.substring(7).trim();
    if (!token) {
      throw ApiError.unauthorized("Authentication token cannot be empty");
    }

    // Verify token with Supabase Auth service
    let supabaseUser;
    try {
      supabaseUser = await verifySupabaseToken(token);
    } catch (err: any) {
      throw ApiError.unauthorized(`Token verification failed: ${err.message || "Invalid or expired token"}`);
    }

    // Resolve user profile & associated student/faculty details directly from database
    const profile = await prisma.profiles.findUnique({
      where: { id: supabaseUser.id },
      include: {
        students: { select: { id: true, roll_number: true, department: true } },
        faculty_details: { select: { id: true, department: true } },
      },
    });

    if (!profile) {
      throw ApiError.unauthorized("User profile not found in database");
    }

    if (!profile.is_active) {
      throw ApiError.forbidden("User account is inactive. Please contact your administrator.");
    }

    req.user = {
      id: supabaseUser.id,
      email: supabaseUser.email,
      role: profile.role as RoleType,
      isActive: profile.is_active,
      profileId: profile.id,
      studentId: profile.students?.id,
      facultyId: profile.faculty_details?.id,
      department: profile.department,
    };

    next();
  } catch (error) {
    next(error);
  }
}

/**
 * Middleware: Requires the authenticated user to have one of the specified roles.
 */
export function requireRole(allowedRoles: RoleType[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      return next(ApiError.unauthorized("Authentication required"));
    }

    if (!allowedRoles.includes(req.user.role)) {
      return next(
        ApiError.forbidden(
          `Access forbidden: required role [${allowedRoles.join(", ")}], but user has [${req.user.role}]`
        )
      );
    }

    next();
  };
}

/**
 * Middleware: Optional authentication. If a Bearer token is provided, authenticates the user,
 * otherwise proceeds without attaching req.user.
 */
export async function optionalAuth(
  req: Request,
  _res: Response,
  next: NextFunction
): Promise<void> {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return next();
  }

  try {
    const token = authHeader.substring(7).trim();
    if (!token) return next();

    const supabaseUser = await verifySupabaseToken(token);
    const profile = await prisma.profiles.findUnique({
      where: { id: supabaseUser.id },
      include: {
        students: { select: { id: true } },
        faculty_details: { select: { id: true } },
      },
    });

    if (profile && profile.is_active) {
      req.user = {
        id: supabaseUser.id,
        email: supabaseUser.email,
        role: profile.role as RoleType,
        isActive: profile.is_active,
        profileId: profile.id,
        studentId: profile.students?.id,
        facultyId: profile.faculty_details?.id,
        department: profile.department,
      };
    }
  } catch (_) {
    // Silently continue if optional auth fails
  }

  next();
}
