import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import { isValidUuid, parsePagination, updateStudentSchema } from "../utils/validators";

export class StudentController {
  /**
   * GET /students
   * Retrieves list of students with pagination and optional filtering by department/batch_year/search.
   */
  static async getAll(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, skip } = parsePagination(req.query);
      const { department, batch_year, search } = req.query;

      const where: any = {};

      if (typeof department === "string" && department.trim()) {
        where.department = {
          contains: department.trim(),
          mode: "insensitive",
        };
      }

      if (batch_year) {
        const year = parseInt(batch_year as string, 10);
        if (!isNaN(year)) {
          where.batch_year = year;
        }
      }

      if (typeof search === "string" && search.trim()) {
        const term = search.trim();
        where.OR = [
          { roll_number: { contains: term, mode: "insensitive" } },
          {
            profiles: {
              full_name: { contains: term, mode: "insensitive" },
            },
          },
        ];
      }

      const [total, students] = await Promise.all([
        prisma.students.count({ where }),
        prisma.students.findMany({
          where,
          skip,
          take: limit,
          orderBy: { created_at: "desc" },
          select: {
            id: true,
            user_id: true,
            roll_number: true,
            department: true,
            batch_year: true,
            created_at: true,
            updated_at: true,
            profiles: {
              select: {
                full_name: true,
                email: true,
                role: true,
                avatar_url: true,
                branch: true,
                enrollment_no: true,
              },
            },
          },
        }),
      ]);

      const formatted = students.map((s) => ({
        id: s.id,
        user_id: s.user_id,
        roll_number: s.roll_number,
        department: s.department,
        batch_year: s.batch_year,
        full_name: s.profiles?.full_name ?? null,
        email: s.profiles?.email ?? null,
        avatar_url: s.profiles?.avatar_url ?? null,
        branch: s.profiles?.branch ?? null,
        enrollment_no: s.profiles?.enrollment_no ?? null,
        created_at: s.created_at,
        updated_at: s.updated_at,
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
   * GET /students/me
   * Retrieves profile and details of the currently authenticated student.
   */
  static async getMe(req: Request, res: Response, next: NextFunction) {
    try {
      if (!req.user) {
        throw ApiError.unauthorized("Authentication required");
      }

      const student = await prisma.students.findUnique({
        where: { user_id: req.user.id },
        include: {
          profiles: {
            select: {
              id: true,
              full_name: true,
              email: true,
              role: true,
              avatar_url: true,
              phone_number: true,
              address: true,
              department: true,
              enrollment_no: true,
              branch: true,
            },
          },
          internships: {
            select: {
              id: true,
              internship_title: true,
              company_name: true,
              status: true,
              start_date: true,
              end_date: true,
              progress: true,
              mode: true,
            },
          },
        },
      });

      if (!student) {
        throw ApiError.notFound("No student profile linked to this user account");
      }

      return sendSuccess(res, student);
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /students/:id
   * Retrieves a single student by UUID with safe fields and related internships.
   */
  static async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const id = typeof req.params.id === "string" ? req.params.id : req.params.id?.[0] || "";

      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid student ID: must be a valid UUID");
      }

      const student = await prisma.students.findUnique({
        where: { id },
        include: {
          profiles: {
            select: {
              id: true,
              full_name: true,
              email: true,
              role: true,
              avatar_url: true,
              phone_number: true,
              address: true,
              department: true,
              enrollment_no: true,
              branch: true,
            },
          },
          internships: {
            select: {
              id: true,
              internship_title: true,
              company_name: true,
              status: true,
              start_date: true,
              end_date: true,
              progress: true,
              mode: true,
            },
            orderBy: { created_at: "desc" },
          },
        },
      });

      if (!student) {
        throw ApiError.notFound(`Student with ID '${id}' was not found`);
      }

      // Ownership check: if authenticated as student, can only view own profile
      if (req.user && req.user.role === "student" && req.user.studentId !== student.id) {
        throw ApiError.forbidden("Access denied: You can only view your own student record");
      }

      return sendSuccess(res, student);
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /students/:id
   * Updates student and profile information with ownership check.
   */
  static async update(req: Request, res: Response, next: NextFunction) {
    try {
      const id = typeof req.params.id === "string" ? req.params.id : req.params.id?.[0] || "";

      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid student ID: must be a valid UUID");
      }

      const validated = updateStudentSchema.parse(req.body);

      const existing = await prisma.students.findUnique({
        where: { id },
        select: { id: true, user_id: true },
      });

      if (!existing) {
        throw ApiError.notFound(`Student with ID '${id}' was not found`);
      }

      // Permission check: student can only edit themselves; staff/admin can edit any
      if (req.user) {
        const isSelf = req.user.studentId === existing.id || req.user.id === existing.user_id;
        const isStaff = ["faculty_mentor", "tp_officer", "admin"].includes(req.user.role);
        if (!isSelf && !isStaff) {
          throw ApiError.forbidden("Access denied: You cannot modify this student record");
        }
      }

      // Separate updates for students table and profiles table
      const studentUpdate: any = {};
      if (validated.department !== undefined) studentUpdate.department = validated.department;
      if (validated.batch_year !== undefined) studentUpdate.batch_year = validated.batch_year;

      const profileUpdate: any = {};
      if (validated.full_name !== undefined) profileUpdate.full_name = validated.full_name;
      if (validated.phone_number !== undefined) profileUpdate.phone_number = validated.phone_number;
      if (validated.address !== undefined) profileUpdate.address = validated.address;
      if (validated.branch !== undefined) profileUpdate.branch = validated.branch;

      const updated = await prisma.$transaction(async (tx) => {
        if (Object.keys(profileUpdate).length > 0) {
          await tx.profiles.update({
            where: { id: existing.user_id },
            data: { ...profileUpdate, updated_at: new Date() },
          });
        }

        return tx.students.update({
          where: { id },
          data: { ...studentUpdate, updated_at: new Date() },
          include: {
            profiles: {
              select: {
                full_name: true,
                email: true,
                phone_number: true,
                address: true,
                department: true,
                branch: true,
              },
            },
          },
        });
      });

      return sendSuccess(res, updated, { message: "Student record updated successfully" });
    } catch (error) {
      next(error);
    }
  }
}
