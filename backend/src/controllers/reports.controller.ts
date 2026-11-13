import { Request, Response, NextFunction } from "express";
import ExcelJS from "exceljs";
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
        internshipsWithLatestReview,
        facultyStageCount,
        tpStageCount,
        departmentsRaw,
      ] = await Promise.all([
        prisma.internships.findMany({
          select: {
            id: true,
            status: true,
            approval_reviews: {
              orderBy: { created_at: "desc" },
              take: 1,
              select: { status: true },
            },
          },
        }),
        prisma.approval_reviews.count({ where: { review_stage: "faculty" } }),
        prisma.approval_reviews.count({ where: { review_stage: "tp_admin" } }),
        prisma.students.groupBy({
          by: ["department"],
          _count: { id: true },
        }),
      ]);

      const totalInternships = internshipsWithLatestReview.length;
      let pendingApprovals = 0;
      let underReviewApprovals = 0;
      let approvedInternships = 0;
      let rejectedApplications = 0;

      for (const item of internshipsWithLatestReview) {
        const latestStatus =
          item.approval_reviews[0]?.status ||
          (item.status === "planned" ? "pending" : item.status) ||
          "pending";
        if (latestStatus === "pending") pendingApprovals += 1;
        else if (latestStatus === "under_review") underReviewApprovals += 1;
        else if (latestStatus === "approved" || latestStatus === "active" || latestStatus === "completed")
          approvedInternships += 1;
        else if (latestStatus === "rejected") rejectedApplications += 1;
      }

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
   * Export reports in JSON, CSV, or native XLSX format for database operation & external audit.
   */
  static async exportReport(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      const {
        format = "json",
        company,
        department,
        status,
        academic_year,
      } = req.query;

      const whereClause: any = {};

      // Role scoping: Industry supervisors only see internships within their assigned organization
      if (user && user.role === "industry_supervisor") {
        const assignments = await prisma.industry_users.findMany({
          where: { user_id: user.profileId },
          include: { industries: { select: { id: true, name: true } } },
        });

        const industryIds = assignments.map((a) => a.industry_id);
        const companyNames = assignments
          .map((a) => a.industries?.name)
          .filter((n): n is string => Boolean(n));

        const directIndustry = await prisma.industries.findUnique({
          where: { id: user.profileId },
          select: { id: true, name: true },
        });
        if (directIndustry) {
          industryIds.push(directIndustry.id);
          if (directIndustry.name) companyNames.push(directIndustry.name);
        }

        whereClause.OR = [
          { industry_id: { in: industryIds } },
          ...(companyNames.length > 0
            ? [{ company_name: { in: companyNames } }]
            : []),
        ];
      }

      // Filter by status if provided
      if (status && typeof status === "string" && status !== "all") {
        whereClause.status = status as any;
      }

      // Filter by company name if provided
      if (company && typeof company === "string" && company !== "all") {
        whereClause.company_name = { contains: company, mode: "insensitive" };
      }

      // Filter by department if provided
      if (department && typeof department === "string" && department !== "all") {
        whereClause.students = {
          department: { contains: department, mode: "insensitive" },
        };
      }

      // Filter by academic year (e.g. 2024 or 2024-2025)
      if (academic_year && typeof academic_year === "string") {
        const match = academic_year.match(/\d{4}/);
        if (match) {
          const year = parseInt(match[0], 10);
          whereClause.start_date = {
            gte: new Date(`${year}-01-01`),
            lte: new Date(`${year + 1}-12-31`),
          };
        }
      }

      const internships = await prisma.internships.findMany({
        where: whereClause,
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

      // Native XLSX Export with styling & auto-fit columns
      if (format === "xlsx" || format === "excel") {
        const workbook = new ExcelJS.Workbook();
        workbook.creator = "Prashikshan Portal";
        workbook.created = new Date();
        const worksheet = workbook.addWorksheet("Internship Reports");

        worksheet.columns = [
          { header: "Internship ID", key: "internshipId", width: 36 },
          { header: "Student Name", key: "studentName", width: 24 },
          { header: "Student Email", key: "studentEmail", width: 28 },
          { header: "Roll Number", key: "rollNumber", width: 16 },
          { header: "Department", key: "department", width: 18 },
          { header: "Company", key: "company", width: 26 },
          { header: "Title", key: "title", width: 26 },
          { header: "Mode", key: "mode", width: 12 },
          { header: "Status", key: "status", width: 14 },
          { header: "Approval Status", key: "approvalStatus", width: 16 },
          { header: "Progress", key: "progress", width: 12 },
          { header: "Start Date", key: "startDate", width: 14 },
          { header: "End Date", key: "endDate", width: 14 },
        ];

        // Format Header Row
        const headerRow = worksheet.getRow(1);
        headerRow.font = { bold: true, color: { argb: "FFFFFFFF" }, size: 11 };
        headerRow.fill = {
          type: "pattern",
          pattern: "solid",
          fgColor: { argb: "FF1E40AF" }, // Indigo / Blue primary
        };
        headerRow.alignment = { vertical: "middle", horizontal: "center" };
        headerRow.height = 24;

        records.forEach((record) => {
          worksheet.addRow(record);
        });

        // Auto-fit column widths based on maximum length
        worksheet.columns.forEach((column) => {
          let maxLength = column.header ? column.header.length : 10;
          if (column.eachCell) {
            column.eachCell({ includeEmpty: false }, (cell) => {
              const val = cell.value ? cell.value.toString() : "";
              if (val.length > maxLength) {
                maxLength = val.length;
              }
            });
          }
          column.width = Math.min(Math.max(maxLength + 3, 12), 45);
        });

        // Thin borders on data rows
        worksheet.eachRow((row, rowNumber) => {
          if (rowNumber > 1) {
            row.alignment = { vertical: "middle" };
            row.eachCell((cell) => {
              cell.border = {
                top: { style: "thin", color: { argb: "FFE5E7EB" } },
                bottom: { style: "thin", color: { argb: "FFE5E7EB" } },
                left: { style: "thin", color: { argb: "FFE5E7EB" } },
                right: { style: "thin", color: { argb: "FFE5E7EB" } },
              };
            });
          }
        });

        const buffer = await workbook.xlsx.writeBuffer();
        const dateStr = new Date().toISOString().split("T")[0];

        res.setHeader(
          "Content-Type",
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        );
        res.setHeader(
          "Content-Disposition",
          `attachment; filename="prashikshan_report_${dateStr}.xlsx"`
        );
        return res.status(200).send(Buffer.from(buffer));
      }

      // CSV Export
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

      // Default JSON Export
      return sendSuccess(res, records, {
        count: records.length,
        message: "Report records exported successfully",
      });
    } catch (error) {
      next(error);
    }
  }
}
