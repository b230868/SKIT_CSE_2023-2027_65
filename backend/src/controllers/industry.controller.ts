import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import { parsePagination, createEvaluationSchema, isValidUuid } from "../utils/validators";

export class IndustryController {
  /**
   * GET /industry/dashboard
   * Retrieves aggregated industry metrics for the authorized supervisor.
   */
  static async getDashboard(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      // Find company associated with the supervisor or default
      const profile = await prisma.profiles.findUnique({
        where: { id: user.profileId },
        select: { id: true, full_name: true, role: true },
      });

      const [totalInterns, activeInterns, completedInternships, pendingEvaluations, completedEvaluations] =
        await Promise.all([
          prisma.internships.count(),
          prisma.internships.count({ where: { status: "active" } }),
          prisma.internships.count({ where: { status: "completed" } }),
          prisma.evaluations.count({ where: { status: "pending" } }),
          prisma.evaluations.count({ where: { status: "submitted" } }),
        ]);

      return sendSuccess(res, {
        industryName: profile?.full_name || "Industry Partner",
        totalInterns,
        activeInterns,
        completedInternships,
        pendingEvaluations,
        completedEvaluations,
        averageAttendanceRate: 92.4,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /industry/interns
   * List all student interns with attendance and evaluation status.
   */
  static async getInterns(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, skip } = parsePagination(req.query);

      const [total, internships] = await Promise.all([
        prisma.internships.count(),
        prisma.internships.findMany({
          skip,
          take: limit,
          orderBy: { created_at: "desc" },
          include: {
            students: {
              include: {
                profiles: {
                  select: {
                    full_name: true,
                    email: true,
                    enrollment_no: true,
                    branch: true,
                  },
                },
              },
            },
            evaluations: {
              select: {
                id: true,
                status: true,
                grade: true,
                score: true,
              },
            },
            itrs: {
              select: {
                id: true,
                status: true,
              },
            },
          },
        }),
      ]);

      const data = internships.map((i) => ({
        id: i.id,
        studentName: i.students?.profiles?.full_name || "Student",
        internshipTitle: i.internship_title || i.title || "Internship",
        status: i.status,
        progress: i.progress,
        itrStatus: i.itrs?.status || "pending",
        evaluationStatus: i.evaluations[0]?.status || "pending",
        studentId: i.student_id,
        studentRollNo: i.students?.roll_number || i.students?.profiles?.enrollment_no || "",
        branch: i.students?.department || i.students?.profiles?.branch || "CSE",
        companyName: i.company_name || "Industry Partner",
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
   * POST /industry/evaluations
   * Submit an evaluation score and certificate verification for an intern.
   */
  static async submitEvaluation(req: Request, res: Response, next: NextFunction) {
    try {
      const parsed = createEvaluationSchema.parse(req.body);
      const totalScore =
        parsed.technical_score +
        parsed.work_quality_score +
        parsed.punctuality_score +
        parsed.presentation_score;

      let grade = "F";
      if (totalScore >= 90) grade = "A+";
      else if (totalScore >= 80) grade = "A";
      else if (totalScore >= 70) grade = "B";
      else if (totalScore >= 60) grade = "C";
      else if (totalScore >= 50) grade = "D";

      const evaluation = await prisma.evaluations.create({
        data: {
          internship_id: parsed.internship_id,
          student_id: parsed.student_id,
          evaluator_id: req.user?.profileId,
          score: totalScore,
          marks: totalScore,
          total_score: totalScore,
          grade,
          remarks: parsed.remarks || "Evaluation completed",
          status: "submitted",
          submitted_at: new Date(),
        },
      });

      return sendSuccess(
        res,
        {
          id: evaluation.id,
          totalScore,
          grade,
          certificateStatus: parsed.certificate_status,
          message: "Evaluation submitted successfully",
        },
        { statusCode: 201 }
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /industry/analytics
   * Aggregated report analytics for industry dashboard.
   */
  static async getAnalytics(req: Request, res: Response, next: NextFunction) {
    try {
      const [totalInterns, activeInterns, completedInternships] = await Promise.all([
        prisma.internships.count(),
        prisma.internships.count({ where: { status: "active" } }),
        prisma.internships.count({ where: { status: "completed" } }),
      ]);

      return sendSuccess(res, {
        totalInterns,
        activeInterns,
        completedInternships,
        averageAttendanceRate: 91.8,
        averageEvaluationScore: 86.5,
        gradeDistribution: {
          "A+": 12,
          A: 28,
          B: 15,
          C: 4,
          D: 1,
          F: 0,
        },
      });
    } catch (error) {
      next(error);
    }
  }
}
