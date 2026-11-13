import { Request, Response, NextFunction } from "express";
import { Prisma } from "../../generated/prisma/client";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import { parsePagination, createEvaluationSchema, isValidUuid } from "../utils/validators";

async function resolveSupervisorScope(profileId: string): Promise<{
  industryIds: string[];
  companyNames: string[];
  primaryName: string | null;
}> {
  const assignments = await prisma.industry_users.findMany({
    where: { user_id: profileId },
    include: { industries: { select: { id: true, name: true } } },
  });

  if (assignments.length > 0) {
    const industryIds = assignments.map((a) => a.industry_id);
    const companyNames = assignments
      .map((a) => a.industries?.name)
      .filter((n): n is string => Boolean(n && n.trim()));
    return {
      industryIds,
      companyNames,
      primaryName: companyNames[0] || null,
    };
  }

  const directIndustry = await prisma.industries.findUnique({
    where: { id: profileId },
    select: { id: true, name: true },
  });
  if (directIndustry) {
    return {
      industryIds: [directIndustry.id],
      companyNames: directIndustry.name ? [directIndustry.name] : [],
      primaryName: directIndustry.name || null,
    };
  }

  return { industryIds: [], companyNames: [], primaryName: null };
}

function buildInternshipScopeWhere(industryIds: string[], companyNames: string[]) {
  const orConditions: any[] = [{ industry_id: { in: industryIds } }];
  if (companyNames.length > 0) {
    orConditions.push({ company_name: { in: companyNames } });
  }
  return { OR: orConditions };
}

async function computeAttendanceRate(internshipIds: string[] | null): Promise<number> {
  if (internshipIds !== null && internshipIds.length === 0) return 0;
  try {
    const rows =
      internshipIds === null
        ? await prisma.$queryRaw<{ total: number; present: number }[]>`
            SELECT
              COUNT(*)::int AS total,
              COUNT(*) FILTER (WHERE status = 'present')::int AS present
            FROM public.attendance
          `
        : await prisma.$queryRaw<{ total: number; present: number }[]>`
            SELECT
              COUNT(*)::int AS total,
              COUNT(*) FILTER (WHERE status = 'present')::int AS present
            FROM public.attendance
            WHERE internship_id IN (${Prisma.join(internshipIds)})
          `;
    const total = Number(rows[0]?.total ?? 0);
    const present = Number(rows[0]?.present ?? 0);
    if (total <= 0) return 0;
    return Number(((present / total) * 100).toFixed(1));
  } catch {
    return 0;
  }
}

export class IndustryController {
  /**
   * GET /industry/dashboard
   * Retrieves aggregated industry metrics for the authorized supervisor.
   */
  static async getDashboard(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      let internshipWhere: any = {};
      let evaluationWhere: any = {};
      let industryName = "All Partner Organizations";
      let scopedIdsForAttendance: string[] | null = null;

      if (user.role === "industry_supervisor") {
        const scope = await resolveSupervisorScope(user.profileId);
        if (scope.industryIds.length === 0) {
          return sendSuccess(res, {
            industryName: "Unassigned Organization",
            totalInterns: 0,
            activeInterns: 0,
            completedInternships: 0,
            pendingEvaluations: 0,
            completedEvaluations: 0,
            averageAttendanceRate: 0,
          });
        }

        industryName = scope.primaryName || "Industry Partner";
        internshipWhere = buildInternshipScopeWhere(scope.industryIds, scope.companyNames);
        evaluationWhere = { internships: internshipWhere };

        const scopedInternships = await prisma.internships.findMany({
          where: internshipWhere,
          select: { id: true },
        });
        scopedIdsForAttendance = scopedInternships.map((i) => i.id);
      } else {
        const profile = await prisma.profiles.findUnique({
          where: { id: user.profileId },
          select: { full_name: true },
        });
        industryName = profile?.full_name || "Industry Overview";
      }

      const [
        totalInterns,
        activeInterns,
        completedInternships,
        pendingEvaluations,
        completedEvaluations,
        averageAttendanceRate,
      ] = await Promise.all([
        prisma.internships.count({ where: internshipWhere }),
        prisma.internships.count({ where: { ...internshipWhere, status: "active" } }),
        prisma.internships.count({ where: { ...internshipWhere, status: "completed" } }),
        prisma.evaluations.count({ where: { ...evaluationWhere, status: "pending" } }),
        prisma.evaluations.count({
          where: {
            ...evaluationWhere,
            status: { in: ["submitted", "verified", "completed"] },
          },
        }),
        computeAttendanceRate(scopedIdsForAttendance),
      ]);

      return sendSuccess(res, {
        industryName,
        totalInterns,
        activeInterns,
        completedInternships,
        pendingEvaluations,
        completedEvaluations,
        averageAttendanceRate,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /industry/interns
   * List student interns scoped to the authorized supervisor's company.
   */
  static async getInterns(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const { page, limit, skip } = parsePagination(req.query);
      let where: any = {};

      if (user.role === "industry_supervisor") {
        const scope = await resolveSupervisorScope(user.profileId);
        if (scope.industryIds.length === 0) {
          return sendSuccess(res, {
            data: [],
            pagination: { page, limit, total: 0, totalPages: 0 },
          });
        }
        where = buildInternshipScopeWhere(scope.industryIds, scope.companyNames);
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
              orderBy: { created_at: "desc" },
              take: 1,
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

      // Fallback profile lookup when internships.student_id stores profiles.id instead of students.id
      const missingStudentIds = internships
        .filter((i) => !i.students)
        .map((i) => i.student_id);
      const fallbackProfiles = new Map<string, any>();
      const fallbackStudents = new Map<string, any>();

      if (missingStudentIds.length > 0) {
        const [profiles, students] = await Promise.all([
          prisma.profiles.findMany({
            where: { id: { in: missingStudentIds } },
            select: { id: true, full_name: true, email: true, enrollment_no: true, branch: true },
          }),
          prisma.students.findMany({
            where: { user_id: { in: missingStudentIds } },
            select: { user_id: true, roll_number: true, department: true },
          }),
        ]);
        profiles.forEach((p) => fallbackProfiles.set(p.id, p));
        students.forEach((s) => fallbackStudents.set(s.user_id, s));
      }

      const data = internships.map((i) => {
        const fbProfile = fallbackProfiles.get(i.student_id);
        const fbStudent = fallbackStudents.get(i.student_id);

        return {
          id: i.id,
          studentName: i.students?.profiles?.full_name || fbProfile?.full_name || "Student",
          internshipTitle: i.internship_title || i.title || "Internship",
          status: i.status,
          progress: i.progress,
          itrStatus: i.itrs?.status || "pending",
          evaluationStatus: i.evaluations[0]?.status || "pending",
          studentId: i.student_id,
          studentRollNo:
            i.students?.roll_number ||
            i.students?.profiles?.enrollment_no ||
            fbStudent?.roll_number ||
            fbProfile?.enrollment_no ||
            "",
          branch:
            i.students?.department ||
            i.students?.profiles?.branch ||
            fbStudent?.department ||
            fbProfile?.branch ||
            "CSE",
          companyName: i.company_name || "Industry Partner",
        };
      });

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
   * Submit or update an evaluation score for an intern within supervisor's company scope.
   */
  static async submitEvaluation(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const parsed = createEvaluationSchema.parse(req.body);

      const internship = await prisma.internships.findUnique({
        where: { id: parsed.internship_id },
        select: { id: true, industry_id: true, company_name: true, student_id: true },
      });

      if (!internship) {
        throw ApiError.notFound(`Internship '${parsed.internship_id}' not found`);
      }

      if (user.role === "industry_supervisor") {
        const scope = await resolveSupervisorScope(user.profileId);
        const matchesIndustryId = scope.industryIds.includes(internship.industry_id);
        const matchesCompanyName =
          Boolean(internship.company_name) &&
          scope.companyNames.includes(internship.company_name!);
        if (!matchesIndustryId && !matchesCompanyName) {
          throw ApiError.forbidden(
            "Access denied: internship does not belong to your assigned organization"
          );
        }
      }

      const candidateStudentId = parsed.student_id || internship.student_id;
      const studentRow = await prisma.students.findFirst({
        where: {
          OR: [{ id: candidateStudentId }, { user_id: candidateStudentId }],
        },
        select: { id: true },
      });

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

      const existing = await prisma.evaluations.findFirst({
        where: { internship_id: parsed.internship_id },
        orderBy: { created_at: "desc" },
        select: { id: true, score: true, total_score: true, grade: true, status: true },
      });

      const now = new Date();
      const evaluation = existing
        ? await prisma.evaluations.update({
            where: { id: existing.id },
            data: {
              student_id: studentRow?.id ?? null,
              industry_id: internship.industry_id,
              evaluator_id: user.profileId,
              score: totalScore,
              marks: totalScore,
              total_score: totalScore,
              grade,
              remarks: parsed.remarks || "Evaluation completed",
              status: "submitted",
              submitted_at: now,
              updated_at: now,
            },
          })
        : await prisma.evaluations.create({
            data: {
              internship_id: parsed.internship_id,
              student_id: studentRow?.id ?? null,
              industry_id: internship.industry_id,
              evaluator_id: user.profileId,
              score: totalScore,
              marks: totalScore,
              total_score: totalScore,
              grade,
              remarks: parsed.remarks || "Evaluation completed",
              status: "submitted",
              submitted_at: now,
            },
          });

      // Audit Log: Record evaluation history
      try {
        await prisma.$executeRaw`
          INSERT INTO public.evaluation_history (
            evaluation_id, internship_id, student_id, evaluator_id, evaluator_name,
            previous_score, new_score, previous_grade, new_grade, previous_status, new_status, remarks, changed_at
          ) VALUES (
            ${evaluation.id}::uuid,
            ${parsed.internship_id}::uuid,
            ${studentRow?.id ?? null}::uuid,
            ${user.profileId}::uuid,
            ${user.email || 'Supervisor'},
            ${existing ? Number(existing.total_score ?? existing.score) : null},
            ${totalScore},
            ${existing ? existing.grade : null},
            ${grade},
            ${existing ? existing.status : null},
            'submitted',
            ${parsed.remarks || 'Evaluation submitted'},
            NOW()
          )
        `;
      } catch (histErr) {
        console.warn("Failed to write to evaluation_history:", histErr);
      }

      return sendSuccess(
        res,
        {
          id: evaluation.id,
          totalScore,
          grade,
          certificateStatus: parsed.certificate_status,
          message: "Evaluation submitted successfully",
        },
        { statusCode: existing ? 200 : 201 }
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
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      let internshipWhere: any = {};
      let evaluationWhere: any = {};
      let scopedIdsForAttendance: string[] | null = null;

      if (user.role === "industry_supervisor") {
        const scope = await resolveSupervisorScope(user.profileId);
        if (scope.industryIds.length === 0) {
          return sendSuccess(res, {
            totalInterns: 0,
            activeInterns: 0,
            completedInternships: 0,
            averageAttendanceRate: 0,
            averageEvaluationScore: 0,
            gradeDistribution: { "A+": 0, A: 0, B: 0, C: 0, D: 0, F: 0 },
          });
        }
        internshipWhere = buildInternshipScopeWhere(scope.industryIds, scope.companyNames);
        evaluationWhere = { internships: internshipWhere };

        const scopedInternships = await prisma.internships.findMany({
          where: internshipWhere,
          select: { id: true },
        });
        scopedIdsForAttendance = scopedInternships.map((i) => i.id);
      }

      const [
        totalInterns,
        activeInterns,
        completedInternships,
        evaluations,
        averageAttendanceRate,
      ] = await Promise.all([
        prisma.internships.count({ where: internshipWhere }),
        prisma.internships.count({ where: { ...internshipWhere, status: "active" } }),
        prisma.internships.count({ where: { ...internshipWhere, status: "completed" } }),
        prisma.evaluations.findMany({
          where: {
            ...evaluationWhere,
            status: { in: ["submitted", "verified", "completed"] },
          },
          select: { total_score: true, score: true, marks: true, grade: true },
        }),
        computeAttendanceRate(scopedIdsForAttendance),
      ]);

      const gradeDistribution: Record<string, number> = {
        "A+": 0,
        A: 0,
        B: 0,
        C: 0,
        D: 0,
        F: 0,
      };

      let scoreSum = 0;
      let scoreCount = 0;
      for (const ev of evaluations) {
        const numericScore = Number(ev.total_score ?? ev.score ?? ev.marks ?? NaN);
        if (!Number.isNaN(numericScore)) {
          scoreSum += numericScore;
          scoreCount += 1;
        }
        if (ev.grade && Object.prototype.hasOwnProperty.call(gradeDistribution, ev.grade)) {
          gradeDistribution[ev.grade] += 1;
        }
      }

      const averageEvaluationScore =
        scoreCount > 0 ? Number((scoreSum / scoreCount).toFixed(1)) : 0;

      return sendSuccess(res, {
        totalInterns,
        activeInterns,
        completedInternships,
        averageAttendanceRate,
        averageEvaluationScore,
        gradeDistribution,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /industry/evaluations/:internshipId/history
   * Retrieve audit history of evaluations for a specific internship.
   */
  static async getEvaluationHistory(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();
      const internshipId = typeof req.params.internshipId === "string" ? req.params.internshipId : String(req.params.internshipId || "");

      if (!isValidUuid(internshipId)) {
        throw ApiError.badRequest("Invalid internship ID");
      }

      // Scope check if industry supervisor
      if (user.role === "industry_supervisor") {
        const scope = await resolveSupervisorScope(user.profileId);
        const internship = await prisma.internships.findUnique({
          where: { id: internshipId },
          select: { id: true, industry_id: true, company_name: true },
        });
        if (!internship) throw ApiError.notFound("Internship not found");

        const matchesIndustryId = scope.industryIds.includes(internship.industry_id);
        const matchesCompanyName =
          Boolean(internship.company_name) &&
          scope.companyNames.includes(internship.company_name!);
        if (!matchesIndustryId && !matchesCompanyName) {
          throw ApiError.forbidden("Access denied: internship not in your organization");
        }
      }

      const historyRows = await prisma.$queryRaw<any[]>`
        SELECT
          id,
          evaluation_id AS "evaluationId",
          internship_id AS "internshipId",
          student_id AS "studentId",
          evaluator_id AS "evaluatorId",
          evaluator_name AS "evaluatorName",
          previous_score AS "previousScore",
          new_score AS "newScore",
          previous_grade AS "previousGrade",
          new_grade AS "newGrade",
          previous_status AS "previousStatus",
          new_status AS "newStatus",
          remarks,
          changed_at AS "changedAt"
        FROM public.evaluation_history
        WHERE internship_id = ${internshipId}::uuid
        ORDER BY changed_at DESC
      `;

      return sendSuccess(res, historyRows);
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /industry/attendance/batch
   * Mark batch attendance for multiple interns on a specific date.
   */
  static async submitBatchAttendance(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const { date, status = "present", records, internshipIds } = req.body;
      const attendanceDate = date ? new Date(date) : new Date();
      const formattedDate = attendanceDate.toISOString().split("T")[0];

      let targets: Array<{ internshipId: string; status: string; remarks?: string }> = [];
      if (Array.isArray(records) && records.length > 0) {
        targets = records.map((r: any) => ({
          internshipId: r.internshipId,
          status: r.status || status || "present",
          remarks: r.remarks || "",
        }));
      } else if (Array.isArray(internshipIds) && internshipIds.length > 0) {
        targets = internshipIds.map((id: string) => ({
          internshipId: id,
          status: status || "present",
          remarks: "Batch attendance marked",
        }));
      } else {
        throw ApiError.badRequest("Either 'records' or 'internshipIds' must be provided");
      }

      // Supervisor scope verification
      if (user.role === "industry_supervisor") {
        const scope = await resolveSupervisorScope(user.profileId);
        const scopedInternships = await prisma.internships.findMany({
          where: {
            id: { in: targets.map((t) => t.internshipId) },
            ...buildInternshipScopeWhere(scope.industryIds, scope.companyNames),
          },
          select: { id: true, student_id: true },
        });
        const allowedIds = new Set(scopedInternships.map((s) => s.id));
        targets = targets.filter((t) => allowedIds.has(t.internshipId));
      }

      if (targets.length === 0) {
        return sendSuccess(res, {
          processedCount: 0,
          message: "No eligible internships found for batch attendance",
        });
      }

      let processedCount = 0;
      for (const target of targets) {
        const intern = await prisma.internships.findUnique({
          where: { id: target.internshipId },
          select: { student_id: true },
        });
        if (!intern) continue;

        const existing = await prisma.$queryRaw<any[]>`
          SELECT id, remarks FROM public.attendance
          WHERE internship_id = ${target.internshipId}::uuid
            AND date = ${formattedDate}::date
          LIMIT 1
        `;

        if (existing && existing.length > 0) {
          await prisma.$executeRaw`
            UPDATE public.attendance
            SET status = ${target.status},
                remarks = ${target.remarks || existing[0].remarks || "Batch marked"},
                updated_at = NOW()
            WHERE id = ${existing[0].id}::uuid
          `;
        } else {
          await prisma.$executeRaw`
            INSERT INTO public.attendance (
              internship_id, student_id, date, status, remarks, created_at, updated_at
            ) VALUES (
              ${target.internshipId}::uuid,
              ${intern.student_id}::uuid,
              ${formattedDate}::date,
              ${target.status},
              ${target.remarks || "Batch marked"},
              NOW(),
              NOW()
            )
          `;
        }
        processedCount++;
      }

      return sendSuccess(res, {
        processedCount,
        date: formattedDate,
        message: `Successfully processed batch attendance for ${processedCount} intern(s)`,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /industry/affiliation/request
   * Submit an affiliation request to link supervisor account with a company.
   */
  static async submitAffiliationRequest(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const { companyName, companyAddress, contactEmail, contactPhone, designation, website } = req.body;
      if (!companyName || typeof companyName !== "string" || !companyName.trim()) {
        throw ApiError.badRequest("Company name is required");
      }

      const rows = await prisma.$queryRaw<any[]>`
        INSERT INTO public.company_affiliation_requests (
          user_id, company_name, company_address, contact_email, contact_phone, designation, website, status, created_at, updated_at
        ) VALUES (
          ${user.profileId}::uuid,
          ${companyName.trim()},
          ${companyAddress || null},
          ${contactEmail || user.email || null},
          ${contactPhone || null},
          ${designation || "Supervisor"},
          ${website || null},
          'pending',
          NOW(),
          NOW()
        )
        RETURNING id, user_id AS "userId", company_name AS "companyName", status, created_at AS "createdAt"
      `;

      return sendSuccess(res, rows[0], { statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /industry/affiliation/requests
   * View pending and historical company affiliation requests.
   */
  static async getAffiliationRequests(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      let requests: any[];
      if (["admin", "tp_officer"].includes(user.role)) {
        requests = await prisma.$queryRaw<any[]>`
          SELECT
            r.id,
            r.user_id AS "userId",
            p.full_name AS "userName",
            p.email AS "userEmail",
            r.company_name AS "companyName",
            r.company_address AS "companyAddress",
            r.contact_email AS "contactEmail",
            r.contact_phone AS "contactPhone",
            r.designation,
            r.website,
            r.status,
            r.review_remarks AS "reviewRemarks",
            r.reviewed_at AS "reviewedAt",
            r.created_at AS "createdAt"
          FROM public.company_affiliation_requests r
          LEFT JOIN public.profiles p ON p.id = r.user_id
          ORDER BY r.created_at DESC
        `;
      } else {
        requests = await prisma.$queryRaw<any[]>`
          SELECT
            id,
            user_id AS "userId",
            company_name AS "companyName",
            company_address AS "companyAddress",
            contact_email AS "contactEmail",
            contact_phone AS "contactPhone",
            designation,
            website,
            status,
            review_remarks AS "reviewRemarks",
            reviewed_at AS "reviewedAt",
            created_at AS "createdAt"
          FROM public.company_affiliation_requests
          WHERE user_id = ${user.profileId}::uuid
          ORDER BY created_at DESC
        `;
      }

      return sendSuccess(res, requests);
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /industry/affiliation/requests/:id
   * Admin / T&P review and approve/reject supervisor affiliation request.
   */
  static async reviewAffiliationRequest(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();
      if (!["admin", "tp_officer"].includes(user.role)) {
        throw ApiError.forbidden("Only Administrators or T&P Officers can review affiliation requests");
      }

      const id = typeof req.params.id === "string" ? req.params.id : String(req.params.id || "");
      const { status, remarks } = req.body;
      if (!["approved", "rejected"].includes(status)) {
        throw ApiError.badRequest("Status must be 'approved' or 'rejected'");
      }

      const existing = await prisma.$queryRaw<any[]>`
        SELECT * FROM public.company_affiliation_requests WHERE id = ${id}::uuid LIMIT 1
      `;
      if (!existing || existing.length === 0) {
        throw ApiError.notFound("Affiliation request not found");
      }

      const request = existing[0];
      await prisma.$executeRaw`
        UPDATE public.company_affiliation_requests
        SET status = ${status},
            reviewed_by = ${user.profileId}::uuid,
            review_remarks = ${remarks || null},
            reviewed_at = NOW(),
            updated_at = NOW()
        WHERE id = ${id}::uuid
      `;

      if (status === "approved") {
        let industry = await prisma.industries.findFirst({
          where: { name: { equals: request.company_name, mode: "insensitive" } },
        });
        if (!industry) {
          industry = await prisma.industries.create({
            data: {
              name: request.company_name,
              website: request.website || null,
              address: request.company_address || null,
              contact_email: request.contact_email || null,
              contact_phone: request.contact_phone || null,
              status: "approved",
            },
          });
        }

        const existingLink = await prisma.industry_users.findFirst({
          where: { user_id: request.user_id, industry_id: industry.id },
        });
        if (!existingLink) {
          await prisma.industry_users.create({
            data: {
              user_id: request.user_id,
              industry_id: industry.id,
              designation: request.designation || "Supervisor",
            },
          });
        }
      }

      return sendSuccess(res, {
        id,
        status,
        message: `Affiliation request ${status} successfully`,
      });
    } catch (error) {
      next(error);
    }
  }
}
