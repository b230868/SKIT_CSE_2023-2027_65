import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import { AuthUser } from "../middleware/auth";
import {
  isValidUuid,
  parsePagination,
  createInternshipSchema,
  updateInternshipSchema,
  createProgressUpdateSchema,
} from "../utils/validators";

function getStudentIdentifiers(user?: AuthUser): string[] {
  return [user?.studentId, user?.profileId].filter((v): v is string => Boolean(v));
}

async function resolveSupervisorScope(profileId: string): Promise<{
  industryIds: string[];
  companyNames: string[];
}> {
  const assignments = await prisma.industry_users.findMany({
    where: { user_id: profileId },
    include: { industries: { select: { id: true, name: true } } },
  });
  if (assignments.length > 0) {
    return {
      industryIds: assignments.map((a) => a.industry_id),
      companyNames: assignments
        .map((a) => a.industries?.name)
        .filter((n): n is string => Boolean(n && n.trim())),
    };
  }
  const direct = await prisma.industries.findUnique({
    where: { id: profileId },
    select: { id: true, name: true },
  });
  return direct
    ? { industryIds: [direct.id], companyNames: direct.name ? [direct.name] : [] }
    : { industryIds: [], companyNames: [] };
}

async function assertInternshipAccess(
  user: AuthUser | undefined,
  internship: { student_id: string; industry_id: string; company_name: string | null }
) {
  if (!user) throw ApiError.unauthorized();
  if (user.role === "student") {
    const ids = getStudentIdentifiers(user);
    if (!ids.includes(internship.student_id)) {
      throw ApiError.forbidden("Access denied: you can only access your own internship");
    }
  } else if (user.role === "industry_supervisor") {
    const scope = await resolveSupervisorScope(user.profileId);
    const matchesIndustryId = scope.industryIds.includes(internship.industry_id);
    const matchesCompany =
      Boolean(internship.company_name) &&
      scope.companyNames.includes(internship.company_name!);
    if (!matchesIndustryId && !matchesCompany) {
      throw ApiError.forbidden(
        "Access denied: internship does not belong to your assigned organization"
      );
    }
  }
}

export class InternshipController {
  /**
   * GET /internships
   * List internships with status/student/department filtering and pagination.
   * Enforces role scoping: students only see their own; industry supervisors only see their company's.
   */
  static async getAll(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, skip } = parsePagination(req.query);
      const { status, student_id, department } = req.query;

      const where: any = {};

      if (req.user?.role === "student") {
        const studentIds = getStudentIdentifiers(req.user);
        if (studentIds.length === 0) {
          throw ApiError.forbidden("No student profile linked to your user account");
        }
        where.student_id = { in: studentIds };
      } else if (req.user?.role === "industry_supervisor") {
        const scope = await resolveSupervisorScope(req.user.profileId);
        if (scope.industryIds.length === 0) {
          return sendSuccess(res, [], {
            count: 0,
            pagination: { page, limit, total: 0, totalPages: 1 },
          });
        }
        where.OR = [
          { industry_id: { in: scope.industryIds } },
          ...(scope.companyNames.length > 0
            ? [{ company_name: { in: scope.companyNames } }]
            : []),
        ];
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

      const missingStudentIds = internships
        .filter((item) => !item.students)
        .map((item) => item.student_id);
      const fallbackProfiles = new Map<string, any>();
      const fallbackStudents = new Map<string, any>();

      if (missingStudentIds.length > 0) {
        const [profiles, students] = await Promise.all([
          prisma.profiles.findMany({
            where: { id: { in: missingStudentIds } },
            select: { id: true, full_name: true, enrollment_no: true, branch: true },
          }),
          prisma.students.findMany({
            where: { user_id: { in: missingStudentIds } },
            select: { user_id: true, roll_number: true, department: true },
          }),
        ]);
        profiles.forEach((p) => fallbackProfiles.set(p.id, p));
        students.forEach((s) => fallbackStudents.set(s.user_id, s));
      }

      const formatted = internships.map((item) => {
        const fbProfile = fallbackProfiles.get(item.student_id);
        const fbStudent = fallbackStudents.get(item.student_id);
        return {
          id: item.id,
          student_id: item.student_id,
          student_name: item.students?.profiles?.full_name || fbProfile?.full_name || "Unknown",
          roll_number:
            item.students?.roll_number ||
            fbStudent?.roll_number ||
            fbProfile?.enrollment_no ||
            "",
          department:
            item.students?.department || fbStudent?.department || fbProfile?.branch || "",
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
        };
      });

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

      await assertInternshipAccess(req.user, internship);

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

      let candidateStudentId = validated.student_id;
      if (req.user?.role === "student") {
        candidateStudentId = req.user.studentId || req.user.profileId;
        if (!candidateStudentId) {
          throw ApiError.forbidden("No student profile linked to your user account");
        }
      } else if (!candidateStudentId) {
        throw ApiError.badRequest("student_id is required when creating an internship as staff");
      }

      const student = await prisma.students.findFirst({
        where: {
          OR: [{ id: candidateStudentId }, { user_id: candidateStudentId }],
        },
      });
      if (!student) {
        throw ApiError.notFound(`Student with ID '${candidateStudentId}' was not found`);
      }

      const industry = await prisma.industries.findUnique({
        where: { id: validated.industry_id },
      });
      if (!industry) {
        throw ApiError.notFound(`Industry with ID '${validated.industry_id}' was not found`);
      }

      const internship = await prisma.internships.create({
        data: {
          student_id: student.id,
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

      await assertInternshipAccess(req.user, existing);

      if (
        req.user?.role === "student" &&
        validated.status &&
        validated.status !== existing.status
      ) {
        throw ApiError.forbidden("Students cannot directly change internship status");
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
        select: { id: true, student_id: true, industry_id: true, company_name: true },
      });

      if (!internship) {
        throw ApiError.notFound(`Internship with ID '${id}' was not found`);
      }

      await assertInternshipAccess(req.user, internship);

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
        select: { id: true, student_id: true, industry_id: true, company_name: true },
      });

      if (!internship) {
        throw ApiError.notFound(`Internship with ID '${id}' was not found`);
      }

      await assertInternshipAccess(req.user, internship);

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
