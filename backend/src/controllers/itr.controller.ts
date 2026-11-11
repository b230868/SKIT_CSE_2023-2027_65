import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import { parsePagination, reviewItrSchema, isValidUuid } from "../utils/validators";

export class ItrController {
  /**
   * GET /itr
   * List ITR submissions with student and internship associations.
   */
  static async getAll(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, skip } = parsePagination(req.query);
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const where: any = {};
      if (user.role === "student") {
        if (!user.studentId) {
          throw ApiError.forbidden("No student profile found");
        }
        where.student_id = user.studentId;
      }

      const [total, itrs] = await Promise.all([
        prisma.itrs.count({ where }),
        prisma.itrs.findMany({
          where,
          skip,
          take: limit,
          orderBy: { created_at: "desc" },
          include: {
            students: {
              include: {
                profiles: {
                  select: { full_name: true, enrollment_no: true },
                },
              },
            },
            internships: {
              select: {
                internship_title: true,
                title: true,
                company_name: true,
              },
            },
          },
        }),
      ]);

      const data = itrs.map((itr) => ({
        id: itr.id,
        internshipId: itr.internship_id,
        studentId: itr.student_id,
        studentName: itr.students?.profiles?.full_name || "Student",
        internshipTitle: itr.internships?.internship_title || itr.internships?.title || "Internship",
        companyName: itr.internships?.company_name || "Company",
        status: itr.status,
        submittedAt: itr.submitted_at,
        verifiedAt: itr.verified_at,
        projectTitle: itr.project_title,
        workDone: itr.work_done,
        technologiesUsed: itr.technologies_used,
      }));

      return sendSuccess(res, {
        data,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit),
        },
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /itr/:id
   * Retrieve single ITR details.
   */
  static async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const id = typeof req.params.id === "string" ? req.params.id : String(req.params.id || "");
      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid ITR UUID");
      }

      const itr = await prisma.itrs.findUnique({
        where: { id },
        include: {
          students: {
            include: {
              profiles: true,
            },
          },
          internships: true,
        },
      });

      if (!itr) {
        throw ApiError.notFound("ITR not found");
      }

      return sendSuccess(res, itr);
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /itr/:id/review
   * Review an ITR submission, assign scores and verify certificate.
   */
  static async review(req: Request, res: Response, next: NextFunction) {
    try {
      const id = typeof req.params.id === "string" ? req.params.id : String(req.params.id || "");
      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid ITR UUID");
      }

      const parsed = reviewItrSchema.parse(req.body);

      const updated = await prisma.itrs.update({
        where: { id },
        data: {
          status: parsed.status,
          remarks: parsed.remarks,
          reviewer_name: parsed.reviewer_name || req.user?.email || "Reviewer",
          reviewer_id: req.user?.profileId,
          reviewed_at: new Date(),
          verified_at: parsed.status === "approved" ? new Date() : undefined,
        },
      });

      return sendSuccess(res, {
        id: updated.id,
        status: updated.status,
        remarks: updated.remarks,
        reviewedAt: updated.reviewed_at,
        message: "ITR reviewed successfully",
      });
    } catch (error) {
      next(error);
    }
  }
}
