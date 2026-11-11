import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import { isValidUuid } from "../utils/validators";

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
            select: {
              id: true,
              roll_number: true,
              department: true,
              batch_year: true,
              profiles: {
                select: {
                  full_name: true,
                  email: true,
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
          itrs: {
            select: {
              status: true,
            },
          },
          certificates: {
            select: {
              id: true,
              status: true,
            },
          },
        },
      });

      const items = internships.map((item) => {
        const studentName =
          item.students?.profiles?.full_name || "Unknown Student";
        const studentEmail = item.students?.profiles?.email || null;
        const internshipTitle =
          item.internship_title || item.title || "Untitled Internship";
        const latestReview = item.approval_reviews[0];
        const appStatus = latestReview?.status || item.status || "pending";
        const hasPending =
          appStatus === "pending" || appStatus === "under_review";

        return {
          studentId: item.student_id,
          studentName,
          studentEmail,
          internshipId: item.id,
          internshipTitle,
          companyName: item.company_name,
          internshipStatus: item.status,
          applicationStatus: appStatus,
          department: item.students?.department || null,
          rollNumber: item.students?.roll_number || null,
          batchYear: item.students?.batch_year || null,
          progress: item.progress || 0,
          itrStatus: item.itrs?.status || null,
          hasCertificate: !!item.certificates,
          certificateStatus: item.certificates?.status || null,
          hasPendingApprovals: hasPending,
        };
      });

      return sendSuccess(res, items, {
        count: items.length,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /monitoring/students/:id
   * Detailed student monitoring view for a specific student.
   * Matches StudentMonitoringDetail contract in Flutter client.
   */
  static async getStudentDetails(req: Request, res: Response, next: NextFunction) {
    try {
      const idParam = req.params.id;
      const studentId =
        typeof idParam === "string" ? idParam : idParam?.[0] || "";

      if (!isValidUuid(studentId)) {
        throw ApiError.badRequest("Invalid student ID: must be a valid UUID");
      }

      const { internshipId } = req.query;

      const student = await prisma.students.findUnique({
        where: { id: studentId },
        include: {
          profiles: {
            select: {
              id: true,
              full_name: true,
              email: true,
              phone_number: true,
              avatar_url: true,
            },
          },
        },
      });

      if (!student) {
        throw ApiError.notFound(`Student with ID '${studentId}' was not found`);
      }

      // Fetch student's internship
      const internshipWhere: any = { student_id: studentId };
      if (typeof internshipId === "string" && isValidUuid(internshipId)) {
        internshipWhere.id = internshipId;
      }

      const internship = await prisma.internships.findFirst({
        where: internshipWhere,
        orderBy: { created_at: "desc" },
        include: {
          itrs: true,
          certificates: true,
        },
      });

      const detail = {
        studentId: student.id,
        userId: student.profiles?.id,
        studentName: student.profiles?.full_name || "Unknown Student",
        studentEmail: student.profiles?.email || "N/A",
        rollNumber: student.roll_number,
        department: student.department,
        branch: student.department || null,
        batchYear: student.batch_year,
        phone: student.profiles?.phone_number,
        address: null,
        avatarUrl: student.profiles?.avatar_url,
        internshipId: internship?.id || null,
        internshipTitle:
          internship?.internship_title || internship?.title || null,
        companyName: internship?.company_name || null,
        internshipMode: internship?.mode || null,
        internshipStatus: internship?.status || null,
        progress: internship?.progress || 0,
        description: internship?.description || null,
        itrId: internship?.itrs?.id || null,
        itrStatus: internship?.itrs?.status || null,
        itrContent: internship?.itrs?.content || null,
        itrProjectTitle: internship?.internship_title || null,
        itrWorkDone: internship?.itrs?.work_done || null,
        itrTechnologiesUsed: internship?.itrs?.technologies_used || null,
        itrKeyLearnings: internship?.itrs?.key_learnings || null,
        itrDocumentPath: internship?.itrs?.document_path || null,
        certificateId: internship?.certificates?.id || null,
        certificateFilePath: internship?.certificates?.file_path || null,
        certificateStatus: internship?.certificates?.status || null,
      };

      return sendSuccess(res, detail);
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /monitoring/documents/:id
   * Verify or reject student documents/certificates by faculty mentor or T&P officer.
   */
  static async verifyDocument(req: Request, res: Response, next: NextFunction) {
    try {
      const idParam = req.params.id;
      const documentId =
        typeof idParam === "string" ? idParam : idParam?.[0] || "";

      if (!isValidUuid(documentId)) {
        throw ApiError.badRequest("Invalid document ID: must be a valid UUID");
      }

      const { status, remarks, rejectionReason } = req.body;

      if (!status || !["approved", "rejected", "verified"].includes(status)) {
        throw ApiError.badRequest("Status must be 'approved', 'rejected', or 'verified'");
      }

      // Check if certificate exists with this ID
      const cert = await prisma.certificates.findUnique({
        where: { id: documentId },
      });

      if (cert) {
        const newCertStatus =
          status === "approved" || status === "verified" ? "generated" : "pending";
        const updated = await prisma.certificates.update({
          where: { id: documentId },
          data: {
            status: newCertStatus,
            updated_at: new Date(),
          },
        });
        return sendSuccess(res, updated, { message: "Certificate verified successfully" });
      }

      // Check if verification record exists
      const verification = await prisma.verifications.findUnique({
        where: { id: documentId },
      });

      if (verification) {
        const newVerStatus =
          status === "approved" || status === "verified" ? "approved" : "rejected";
        const updated = await prisma.verifications.update({
          where: { id: documentId },
          data: {
            status: newVerStatus,
            remarks: remarks || rejectionReason || null,
            verified_at: new Date(),
            updated_at: new Date(),
          },
        });
        return sendSuccess(res, updated, { message: "Verification record updated successfully" });
      }

      throw ApiError.notFound(`Document with ID '${documentId}' was not found`);
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /monitoring/dashboard
   * Consolidated Faculty/TP dashboard statistics.
   */
  static async getDashboardStats(_req: Request, res: Response, next: NextFunction) {
    try {
      const [
        totalInternships,
        activeInternships,
        completedInternships,
        pendingApprovals,
        totalStudents,
      ] = await Promise.all([
        prisma.internships.count(),
        prisma.internships.count({ where: { status: "active" } }),
        prisma.internships.count({ where: { status: "completed" } }),
        prisma.approval_reviews.count({ where: { status: "pending" } }),
        prisma.students.count(),
      ]);

      return sendSuccess(res, {
        totalInternships,
        activeInternships,
        completedInternships,
        pendingApprovals,
        totalStudents,
      });
    } catch (error) {
      next(error);
    }
  }
}
