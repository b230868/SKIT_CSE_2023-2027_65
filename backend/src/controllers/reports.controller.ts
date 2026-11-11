import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { sendSuccess } from "../utils/response";

export class ReportsController {
  /**
   * GET /reports/faculty
   * Detailed reports for Faculty Mentors.
   */
  static async getFacultyReport(req: Request, res: Response, next: NextFunction) {
    try {
      const [
        totalInternships,
        pendingApprovals,
        underReviewApprovals,
        approvedInternships,
        rejectedApplications,
        facultyStageCount,
        tpStageCount,
        departmentsRaw,
      ] = await Promise.all([
        prisma.internships.count(),
        prisma.approval_reviews.count({ where: { status: "pending" } }),
        prisma.approval_reviews.count({ where: { status: "under_review" } }),
        prisma.approval_reviews.count({ where: { status: "approved" } }),
        prisma.approval_reviews.count({ where: { status: "rejected" } }),
        prisma.approval_reviews.count({ where: { review_stage: "faculty" } }),
        prisma.approval_reviews.count({ where: { review_stage: "tp_admin" } }),
        prisma.students.groupBy({
          by: ["department"],
          _count: { id: true },
        }),
      ]);

      const departmentSummary: Record<string, number> = {};
      departmentsRaw.forEach((d) => {
        if (d.department) {
          departmentSummary[d.department] = d._count.id;
        }
      });

      const approvalRate =
        totalInternships > 0
          ? Number(((approvedInternships / totalInternships) * 100).toFixed(2))
          : 0;

      return sendSuccess(res, {
        totalInternships,
        pendingApprovals,
        underReviewApprovals,
        approvedInternships,
        rejectedApplications,
        facultyStageCount,
        tpStageCount,
        departmentSummary,
        approvalRate,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /reports/tp
   * Aggregated Training & Placement statistics.
   */
  static async getTpReport(req: Request, res: Response, next: NextFunction) {
    try {
      const [
        totalStudents,
        activeInternships,
        completedInternships,
        companiesCount,
        verifiedCertificates,
        topIndustriesRaw,
      ] = await Promise.all([
        prisma.students.count(),
        prisma.internships.count({ where: { status: "active" } }),
        prisma.internships.count({ where: { status: "completed" } }),
        prisma.industries.count(),
        prisma.certificates.count({ where: { status: "generated" } }),
        prisma.internships.groupBy({
          by: ["company_name"],
          _count: { id: true },
          orderBy: { _count: { id: "desc" } },
          take: 5,
        }),
      ]);

      const topCompanies = topIndustriesRaw.map((row) => ({
        company: row.company_name || "Unspecified",
        internsCount: row._count.id,
      }));

      const placementRate =
        totalStudents > 0
          ? Number((((activeInternships + completedInternships) / totalStudents) * 100).toFixed(2))
          : 0;

      return sendSuccess(res, {
        totalStudents,
        activeInternships,
        completedInternships,
        companiesCount,
        verifiedCertificates,
        placementRate,
        topCompanies,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /reports/export
   * Export reports in JSON or CSV format for database operation & external audit.
   */
  static async exportReport(req: Request, res: Response, next: NextFunction) {
    try {
      const { format = "json" } = req.query;

      const internships = await prisma.internships.findMany({
        orderBy: { created_at: "desc" },
        include: {
          students: {
            include: {
              profiles: {
                select: {
                  full_name: true,
                  email: true,
                },
              },
            },
          },
          industries: {
            select: {
              name: true,
            },
          },
          approval_reviews: {
            take: 1,
            orderBy: { created_at: "desc" },
            select: {
              status: true,
              review_stage: true,
            },
          },
        },
      });

      const records = internships.map((i) => ({
        internshipId: i.id,
        studentName: i.students?.profiles?.full_name || "Unknown",
        studentEmail: i.students?.profiles?.email || "N/A",
        rollNumber: i.students?.roll_number || "N/A",
        department: i.students?.department || "N/A",
        company: i.industries?.name || i.company_name || "N/A",
        title: i.internship_title || i.title || "N/A",
        mode: i.mode,
        status: i.status,
        approvalStatus: i.approval_reviews[0]?.status || "pending",
        progress: `${i.progress}%`,
        startDate: i.start_date.toISOString().split("T")[0],
        endDate: i.end_date.toISOString().split("T")[0],
      }));

      if (format === "csv") {
        const headers = [
          "Internship ID",
          "Student Name",
          "Student Email",
          "Roll Number",
          "Department",
          "Company",
          "Title",
          "Mode",
          "Status",
          "Approval Status",
          "Progress",
          "Start Date",
          "End Date",
        ];

        const rows = records.map((r) =>
          [
            r.internshipId,
            `"${r.studentName}"`,
            r.studentEmail,
            r.rollNumber,
            `"${r.department}"`,
            `"${r.company}"`,
            `"${r.title}"`,
            r.mode,
            r.status,
            r.approvalStatus,
            r.progress,
            r.startDate,
            r.endDate,
          ].join(",")
        );

        const csvContent = [headers.join(","), ...rows].join("\n");

        res.setHeader("Content-Type", "text/csv");
        res.setHeader(
          "Content-Disposition",
          `attachment; filename="prashikshan_report_${new Date().toISOString().split("T")[0]}.csv"`
        );
        return res.status(200).send(csvContent);
      }

      return sendSuccess(res, records, {
        count: records.length,
        message: "Report records exported successfully",
      });
    } catch (error) {
      next(error);
    }
  }
}
