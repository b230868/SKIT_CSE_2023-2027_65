import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import {
  isValidUuid,
  parsePagination,
  createInternshipSchema,
  updateInternshipSchema,
  createProgressUpdateSchema,
} from "../utils/validators";

export class InternshipController {
  /**
   * GET /internships
   * List internships with status/student/department filtering and pagination.
   * Enforces role scoping: students only see their own internships.
   */
  static async getAll(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, skip } = parsePagination(req.query);
      const { status, student_id, department } = req.query;

      const where: any = {};

      // Role-based scoping
      if (req.user?.role === "student") {
        if (!req.user.studentId) {
          throw ApiError.forbidden("No student profile linked to your user account");
        }
        where.student_id = req.user.studentId;
      } else if (typeof student_id === "string" && student_id.trim()) {
        if (!isValidUuid(student_id)) {
          throw ApiError.badRequest("Invalid student_id parameter: must be a valid UUID");
        }
        where.student_id = student_id.trim();
      }

      if (typeof status === "string" && status.trim()) {
        where.status = status.trim();
      }

      if (typeof department === "string" && department.trim()) {
        where.students = {
          department: {
            contains: department.trim(),
            mode: "insensitive",
          },
        };
      }

      const [total, internships] = await Promise.all([
        prisma.internships.count({ where }),
        prisma.internships.findMany({
          where,
          skip,
          take: limit,
          orderBy: { created_at: "desc" },
          include: {
            students: {
              select: {
                id: true,
                roll_number: true,
                department: true,
                profiles: {
                  select: {
                    full_name: true,
                    email: true,
                    avatar_url: true,
                  },
                },
              },
            },
            industries: {
              select: {
                id: true,
                name: true,
              },
            },
          },
        }),
      ]);

      const formatted = internships.map((item) => ({
        id: item.id,
        student_id: item.student_id,
        student_name: item.students?.profiles?.full_name || "Unknown",
        roll_number: item.students?.roll_number || "",
        department: item.students?.department || "",
        industry_id: item.industry_id,
        industry_name: item.industries?.name || item.company_name || "N/A",
        internship_title: item.internship_title || item.title || "Untitled",
        company_name: item.company_name,
        mode: item.mode,
        status: item.status,
        progress: item.progress,
        start_date: item.start_date,
        end_date: item.end_date,
        created_at: item.created_at,
        updated_at: item.updated_at,
      }));

      return sendSuccess(res, formatted, {
        count: formatted.length,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit) || 1,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /internships/:id
   * Get single internship by UUID with full details, progress updates, and reviews.
   */
  static async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const id = typeof req.params.id === "string" ? req.params.id : req.params.id?.[0] || "";

      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid internship ID: must be a valid UUID");
      }

      const internship = await prisma.internships.findUnique({
        where: { id },
        include: {
          students: {
            include: {
              profiles: {
                select: {
                  full_name: true,
                  email: true,
                  avatar_url: true,
                  phone_number: true,
                },
              },
            },
          },
          industries: true,
          approval_reviews: {
            include: {
              profiles: {
                select: {
                  full_name: true,
                  role: true,
                },
              },
            },
            orderBy: { created_at: "desc" },
          },
          internship_progress_updates: {
            orderBy: { created_at: "desc" },
            take: 10,
          },
        },
      });

      if (!internship) {
        throw ApiError.notFound(`Internship with ID '${id}' was not found`);
      }

      // Role check: student can only view their own internship
      if (req.user?.role === "student" && req.user.studentId !== internship.student_id) {
        throw ApiError.forbidden("Access denied: You can only view your own internship records");
      }

      return sendSuccess(res, internship);
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /internships
   * Create a new internship record.
   */
  static async create(req: Request, res: Response, next: NextFunction) {
    try {
      const validated = createInternshipSchema.parse(req.body);

      // Determine student_id: if user is student, enforce their student ID
      let studentId = validated.student_id;
      if (req.user?.role === "student") {
        if (!req.user.studentId) {
          throw ApiError.forbidden("No student profile linked to your user account");
        }
        studentId = req.user.studentId;
      } else if (!studentId) {
        throw ApiError.badRequest("student_id is required when creating an internship as staff");
      }

      // Verify student exists
      const student = await prisma.students.findUnique({
        where: { id: studentId },
      });
      if (!student) {
        throw ApiError.notFound(`Student with ID '${studentId}' was not found`);
      }

      // Verify industry exists
      const industry = await prisma.industries.findUnique({
        where: { id: validated.industry_id },
      });
      if (!industry) {
        throw ApiError.notFound(`Industry with ID '${validated.industry_id}' was not found`);
      }

      const internship = await prisma.internships.create({
        data: {
          student_id: studentId,
          industry_id: validated.industry_id,
          start_date: new Date(validated.start_date),
          end_date: new Date(validated.end_date),
          internship_title: validated.internship_title,
          title: validated.title || validated.internship_title,
          company_name: validated.company_name || industry.name,
          mode: validated.mode,
          description: validated.description,
          status: "planned",
          progress: 0,
        },
      });

      return sendSuccess(res, internship, {
        statusCode: 201,
        message: "Internship created successfully",
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /internships/:id
   * Update internship details or status.
   */
  static async update(req: Request, res: Response, next: NextFunction) {
    try {
      const id = typeof req.params.id === "string" ? req.params.id : req.params.id?.[0] || "";

      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid internship ID: must be a valid UUID");
      }

      const validated = updateInternshipSchema.parse(req.body);

      const existing = await prisma.internships.findUnique({
        where: { id },
      });

      if (!existing) {
        throw ApiError.notFound(`Internship with ID '${id}' was not found`);
      }

      // Permission check: student can only update their own; status changes may require staff
      if (req.user?.role === "student") {
        if (req.user.studentId !== existing.student_id) {
          throw ApiError.forbidden("Access denied: You can only update your own internship");
        }
        if (validated.status && validated.status !== existing.status) {
          throw ApiError.forbidden("Students cannot directly change internship status");
        }
      }

      const updateData: any = { ...validated, updated_at: new Date() };

      const updated = await prisma.internships.update({
        where: { id },
        data: updateData,
      });

      return sendSuccess(res, updated, { message: "Internship updated successfully" });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /internships/:id/progress
   * Retrieves all progress updates for an internship.
   */
  static async getProgress(req: Request, res: Response, next: NextFunction) {
    try {
      const id = typeof req.params.id === "string" ? req.params.id : req.params.id?.[0] || "";

      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid internship ID: must be a valid UUID");
      }

      const internship = await prisma.internships.findUnique({
        where: { id },
        select: { id: true, student_id: true },
      });

      if (!internship) {
        throw ApiError.notFound(`Internship with ID '${id}' was not found`);
      }

      if (req.user?.role === "student" && req.user.studentId !== internship.student_id) {
        throw ApiError.forbidden("Access denied: You can only view progress of your own internship");
      }

      const updates = await prisma.internship_progress_updates.findMany({
        where: { internship_id: id },
        orderBy: { created_at: "desc" },
        include: {
          profiles: {
            select: {
              full_name: true,
              role: true,
            },
          },
        },
      });

      return sendSuccess(res, updates, { count: updates.length });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /internships/:id/progress
   * Adds a new progress update and updates internship progress percentage.
   */
  static async addProgress(req: Request, res: Response, next: NextFunction) {
    try {
      const id = typeof req.params.id === "string" ? req.params.id : req.params.id?.[0] || "";

      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid internship ID: must be a valid UUID");
      }

      if (!req.user) {
        throw ApiError.unauthorized("Authentication required");
      }

      const validated = createProgressUpdateSchema.parse(req.body);

      const internship = await prisma.internships.findUnique({
        where: { id },
        select: { id: true, student_id: true },
      });

      if (!internship) {
        throw ApiError.notFound(`Internship with ID '${id}' was not found`);
      }

      // Check ownership
      if (req.user.role === "student" && req.user.studentId !== internship.student_id) {
        throw ApiError.forbidden("Access denied: You can only post progress for your own internship");
      }

      const [newUpdate] = await prisma.$transaction([
        prisma.internship_progress_updates.create({
          data: {
            internship_id: id,
            updated_by: req.user.id,
            progress_percentage: validated.progress_percentage,
            update_text: validated.update_text,
          },
        }),
        prisma.internships.update({
          where: { id },
          data: {
            progress: validated.progress_percentage,
            updated_at: new Date(),
          },
        }),
      ]);

      return sendSuccess(res, newUpdate, {
        statusCode: 201,
        message: "Progress update logged successfully",
      });
    } catch (error) {
      next(error);
    }
  }
}
