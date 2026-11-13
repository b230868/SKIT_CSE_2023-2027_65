import { Request, Response, NextFunction } from "express";
import { Prisma } from "../../generated/prisma/client";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import { isValidUuid } from "../utils/validators";

async function fetchAttendanceRatesByInternship(
  internshipIds: string[]
): Promise<Map<string, number>> {
  const rates = new Map<string, number>();
  if (internshipIds.length === 0) return rates;

  try {
    const rows = await prisma.$queryRaw<
      { internship_id: string; total: number; present: number }[]
    >`
      SELECT
        internship_id,
        COUNT(*)::int AS total,
        COUNT(*) FILTER (WHERE status = 'present')::int AS present
      FROM public.attendance
      WHERE internship_id IN (${Prisma.join(internshipIds)})
      GROUP BY internship_id
    `;
    for (const row of rows) {
      if (row.total > 0) {
        rates.set(row.internship_id, Number(((row.present / row.total) * 100).toFixed(1)));
      }
    }
  } catch {
    // Table may not exist on older environments; fall back gracefully
  }
  return rates;
}

async function fetchDocumentsByInternship(
  internshipIds: string[]
): Promise<Map<string, any[]>> {
  const docsMap = new Map<string, any[]>();
  if (internshipIds.length === 0) return docsMap;

  try {
    const rows = await prisma.$queryRaw<any[]>`
      SELECT
        id,
        internship_id,
        doc_type,
        file_name,
        file_path,
        status,
        rejection_reason,
        remarks,
        verified_by_name,
        verified_at,
        faculty_status,
        faculty_rejection_reason,
        faculty_remarks,
        faculty_verified_by_name,
        faculty_verified_at,
        created_at
      FROM public.internship_documents
      WHERE internship_id IN (${Prisma.join(internshipIds)})
      ORDER BY created_at DESC
    `;

    for (const row of rows) {
      const list = docsMap.get(row.internship_id) || [];
      list.push({
        id: row.id,
        internship_id: row.internship_id,
        doc_type: row.doc_type || "other",
        file_name: row.file_name || "Document",
        name: row.file_name || "Document",
        file_path: row.file_path,
        status: row.status || "pending",
        rejection_reason: row.rejection_reason,
        remarks: row.remarks,
        verified_by_name: row.verified_by_name,
        verified_at: row.verified_at,
        faculty_status: row.faculty_status || "pending",
        faculty_rejection_reason: row.faculty_rejection_reason,
        faculty_remarks: row.faculty_remarks,
        faculty_verified_by_name: row.faculty_verified_by_name,
        faculty_verified_at: row.faculty_verified_at,
        created_at: row.created_at,
        uploaded_at: row.created_at,
      });
      docsMap.set(row.internship_id, list);
    }
  } catch {
    // Table may not exist on older environments; fall back gracefully
  }
  return docsMap;
}

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
          evaluations: {
            orderBy: { created_at: "desc" },
            take: 1,
            select: {
              total_score: true,
              score: true,
              marks: true,
              grade: true,
              remarks: true,
              profiles: {
                select: {
                  full_name: true,
                },
              },
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

      const missingStudentIds = internships
        .filter((i) => !i.students)
        .map((i) => i.student_id);
      const fallbackProfiles = new Map<string, any>();
      const fallbackStudents = new Map<string, any>();

      if (missingStudentIds.length > 0) {
        const [profiles, students] = await Promise.all([
          prisma.profiles.findMany({
            where: { id: { in: missingStudentIds } },
            select: {
              id: true,
              full_name: true,
              email: true,
              enrollment_no: true,
              branch: true,
              department: true,
            },
          }),
          prisma.students.findMany({
            where: { user_id: { in: missingStudentIds } },
            select: {
              user_id: true,
              roll_number: true,
              department: true,
              batch_year: true,
            },
          }),
        ]);
        profiles.forEach((p) => fallbackProfiles.set(p.id, p));
        students.forEach((s) => fallbackStudents.set(s.user_id, s));
      }

      const internshipIds = internships.map((i) => i.id);
      const [attendanceRates, documentsByInternship] = await Promise.all([
        fetchAttendanceRatesByInternship(internshipIds),
        fetchDocumentsByInternship(internshipIds),
      ]);

      const items = internships.map((item) => {
        const fbProfile = fallbackProfiles.get(item.student_id);
        const fbStudent = fallbackStudents.get(item.student_id);

        const studentName =
          item.students?.profiles?.full_name || fbProfile?.full_name || "Unknown Student";
        const studentEmail =
          item.students?.profiles?.email || fbProfile?.email || null;
        const internshipTitle =
          item.internship_title || item.title || "Untitled Internship";
        const latestReview = item.approval_reviews[0];
        const appStatus = latestReview?.status || item.status || "pending";
        const hasPending =
          appStatus === "pending" || appStatus === "under_review";
        const latestEval = item.evaluations[0];
        const rawScore = latestEval?.total_score ?? latestEval?.score ?? latestEval?.marks;
        const cert = Array.isArray(item.certificates)
          ? item.certificates[0]
          : item.certificates;

        return {
          studentId: item.student_id,
          studentName,
          studentEmail,
          internshipId: item.id,
          internshipTitle,
          companyName: item.company_name,
          internshipStatus: item.status,
          applicationStatus: appStatus,
          department:
            item.students?.department ||
            fbStudent?.department ||
            fbProfile?.department ||
            fbProfile?.branch ||
            null,
          rollNumber:
            item.students?.roll_number ||
            fbStudent?.roll_number ||
            fbProfile?.enrollment_no ||
            null,
          batchYear: item.students?.batch_year || fbStudent?.batch_year || null,
          progress: item.progress || 0,
          itrStatus: item.itrs?.status || null,
          hasCertificate: Boolean(cert),
          certificateStatus: cert?.status || null,
          hasPendingApprovals: hasPending,
          companyEvaluationScore:
            rawScore !== null && rawScore !== undefined ? Number(rawScore) : null,
          companyEvaluationGrade: latestEval?.grade || null,
          companyRemarks: latestEval?.remarks || null,
          companyEvaluatorName: latestEval?.profiles?.full_name || null,
          attendanceRate: attendanceRates.get(item.id) ?? null,
          documents: documentsByInternship.get(item.id) || [],
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

      const student = await prisma.students.findFirst({
        where: { OR: [{ id: studentId }, { user_id: studentId }] },
        include: {
          profiles: {
            select: {
              id: true,
              full_name: true,
              email: true,
              phone_number: true,
              phone: true,
              address: true,
              avatar_url: true,
              enrollment_no: true,
              department: true,
              branch: true,
            },
          },
        },
      });

      const fallbackProfile = student
        ? null
        : await prisma.profiles.findUnique({
            where: { id: studentId },
            select: {
              id: true,
              full_name: true,
              email: true,
              phone_number: true,
              phone: true,
              address: true,
              avatar_url: true,
              enrollment_no: true,
              department: true,
              branch: true,
            },
          });

      if (!student && !fallbackProfile) {
        throw ApiError.notFound(`Student with ID '${studentId}' was not found`);
      }

      const candidateStudentIds = Array.from(
        new Set(
          [student?.id, student?.user_id, student?.profiles?.id, fallbackProfile?.id].filter(
            (v): v is string => Boolean(v)
          )
        )
      );

      const internshipWhere: any = { student_id: { in: candidateStudentIds } };
      if (typeof internshipId === "string" && isValidUuid(internshipId)) {
        internshipWhere.id = internshipId;
      }

      const internship = await prisma.internships.findFirst({
        where: internshipWhere,
        orderBy: { created_at: "desc" },
        include: {
          industries: {
            select: {
              name: true,
              address: true,
              contact_email: true,
              contact_phone: true,
            },
          },
          itrs: {
            include: {
              profiles: {
                select: { full_name: true },
              },
            },
          },
          certificates: true,
          evaluations: {
            orderBy: { created_at: "desc" },
            take: 1,
            include: {
              profiles: { select: { full_name: true } },
            },
          },
          approval_reviews: {
            orderBy: { created_at: "desc" },
            include: {
              profiles: { select: { full_name: true, role: true } },
            },
          },
        },
      });

      const [attendanceRates, documentsByInternship] = internship
        ? await Promise.all([
            fetchAttendanceRatesByInternship([internship.id]),
            fetchDocumentsByInternship([internship.id]),
          ])
        : [new Map<string, number>(), new Map<string, any[]>()];

      const profileData = student?.profiles || fallbackProfile;
      const latestEval = internship?.evaluations?.[0];
      const evalRawScore =
        latestEval?.total_score ?? latestEval?.score ?? latestEval?.marks;
      const cert = Array.isArray(internship?.certificates)
        ? internship?.certificates[0]
        : internship?.certificates;

      const detail = {
        studentId: student?.id || profileData!.id,
        userId: profileData?.id,
        studentName: profileData?.full_name || "Unknown Student",
        studentEmail: profileData?.email || "N/A",
        rollNumber: student?.roll_number || profileData?.enrollment_no || null,
        department: student?.department || profileData?.department || profileData?.branch || null,
        branch: student?.department || profileData?.branch || profileData?.department || null,
        batchYear: student?.batch_year || null,
        phone: profileData?.phone_number || profileData?.phone || null,
        address: profileData?.address || null,
        avatarUrl: profileData?.avatar_url || null,
        internshipId: internship?.id || null,
        internshipTitle:
          internship?.internship_title || internship?.title || null,
        companyName: internship?.industries?.name || internship?.company_name || null,
        industryName: internship?.industries?.name || internship?.company_name || null,
        industryAddress: internship?.industries?.address || null,
        industryEmail: internship?.industries?.contact_email || null,
        industryPhone: internship?.industries?.contact_phone || null,
        internshipMode: internship?.mode || null,
        internshipStatus: internship?.status || null,
        startDate: internship?.start_date || null,
        endDate: internship?.end_date || null,
        progress: internship?.progress || 0,
        description: internship?.description || null,
        itrId: internship?.itrs?.id || null,
        itrStatus: internship?.itrs?.status || null,
        itrContent: internship?.itrs?.content || null,
        itrProjectTitle:
          internship?.itrs?.project_title || internship?.internship_title || null,
        itrProjectDescription: internship?.itrs?.project_description || null,
        itrWorkDone: internship?.itrs?.work_done || null,
        itrTechnologiesUsed: internship?.itrs?.technologies_used || null,
        itrKeyLearnings: internship?.itrs?.key_learnings || null,
        itrChallengesFaced: internship?.itrs?.challenges_faced || null,
        itrDocumentPath: internship?.itrs?.document_path || null,
        itrProjectZipPath: internship?.itrs?.project_zip_path || null,
        itrPresentationPath:
          internship?.itrs?.presentation_path ||
          internship?.itrs?.project_presentation_path ||
          internship?.itrs?.project_ppt_path ||
          null,
        itrSubmittedAt: internship?.itrs?.submitted_at || null,
        itrReviewedAt: internship?.itrs?.reviewed_at || null,
        itrVerifiedAt: internship?.itrs?.verified_at || null,
        itrReviewerName:
          internship?.itrs?.reviewer_name || internship?.itrs?.profiles?.full_name || null,
        itrRemarks: internship?.itrs?.remarks || null,
        certificateId: cert?.id || null,
        certificateFilePath: cert?.file_path || cert?.document_path || null,
        certificateStatus: cert?.status || null,
        companyEvaluationScore:
          evalRawScore !== null && evalRawScore !== undefined ? Number(evalRawScore) : null,
        companyEvaluationGrade: latestEval?.grade || null,
        companyRemarks: latestEval?.remarks || null,
        companyEvaluatorName: latestEval?.profiles?.full_name || null,
        attendanceRate: internship ? attendanceRates.get(internship.id) ?? null : null,
        documents: internship ? documentsByInternship.get(internship.id) || [] : [],
        approvalReviews: (internship?.approval_reviews || []).map((r) => ({
          id: r.id,
          reviewStage: r.review_stage,
          status: r.status,
          remarks: r.remarks,
          reviewerName: r.profiles?.full_name || "Reviewer",
          reviewerRole: r.profiles?.role || null,
          createdAt: r.created_at,
        })),
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

      const normalizedFacultyStatus =
        status === "approved" || status === "verified" ? "approved" : "rejected";

      // Check internship_documents first
      try {
        let reviewerName: string | null = null;
        if (req.user?.profileId) {
          const reviewer = await prisma.profiles.findUnique({
            where: { id: req.user.profileId },
            select: { full_name: true },
          });
          reviewerName = reviewer?.full_name || req.user.email || null;
        }

        const updatedDocs = await prisma.$queryRaw<any[]>`
          UPDATE public.internship_documents
          SET
            faculty_status = ${normalizedFacultyStatus},
            faculty_rejection_reason = ${normalizedFacultyStatus === "rejected" ? (rejectionReason || remarks || null) : null},
            faculty_remarks = ${remarks || null},
            faculty_verified_by = ${req.user?.profileId || null}::uuid,
            faculty_verified_by_name = ${reviewerName},
            faculty_verified_at = now()
          WHERE id = ${documentId}::uuid
          RETURNING id, faculty_status, faculty_rejection_reason, faculty_remarks, faculty_verified_at
        `;

        if (updatedDocs.length > 0) {
          return sendSuccess(res, updatedDocs[0], {
            message: "Student document verification updated successfully",
          });
        }
      } catch {
        // Ignore if internship_documents table/columns differ and fall through to certificates/verifications
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
