import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { sendSuccess } from "../utils/response";

export class MonitoringController {
  /**
   * GET /monitoring/students
   * Retrieves aggregated student monitoring list for Faculty Mentors and T&P Officers.
   * Matches the StudentMonitoringItem contract used by the Flutter application.
   */
  static async getStudents(req: Request, res: Response, next: NextFunction) {
    try {
      const { department, status } = req.query;

      const where: any = {};

      if (typeof department === "string" && department.trim()) {
        where.students = {
          department: { contains: department.trim(), mode: "insensitive" },
        };
      }

      if (typeof status === "string" && status.trim()) {
        where.status = status.trim();
      }

      const internships = await prisma.internships.findMany({
        where,
        orderBy: { created_at: "desc" },
        include: {
          students: {
            include: {
              profiles: {
                select: {
                  full_name: true,
                },
              },
            },
          },
          approval_reviews: {
            orderBy: { created_at: "desc" },
            take: 1,
            select: {
              status: true,
              review_stage: true,
              created_at: true,
            },
          },
        },
      });

      const items = internships.map((item) => {
        const studentName =
          item.students?.profiles?.full_name || "Unknown Student";
        const internshipTitle =
          item.internship_title || item.title || "Untitled Internship";
        const latestReview = item.approval_reviews[0];
        const applicationStatus = latestReview?.status || item.status || "pending";

        return {
          studentId: item.student_id,
          studentName,
          internshipId: item.id,
          internshipTitle,
          applicationStatus,
          department: item.students?.department || null,
          rollNumber: item.students?.roll_number || null,
        };
      });

      return sendSuccess(res, items, {
        count: items.length,
      });
    } catch (error) {
      next(error);
    }
  }
}
