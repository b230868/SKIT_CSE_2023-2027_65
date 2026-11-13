import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import { parsePagination, reviewItrSchema, isValidUuid } from "../utils/validators";

async function resolveIndustryScope(profileId: string): Promise<{
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

export class ItrController {
  /**
   * GET /itr
   * List ITR submissions with role scoping and student/internship associations.
   */
  static async getAll(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, skip } = parsePagination(req.query);
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const where: any = {};
      if (user.role === "student") {
        const studentIds = [user.studentId, user.profileId].filter(
          (v): v is string => Boolean(v)
        );
        if (studentIds.length === 0) {
          throw ApiError.forbidden("No student profile found");
        }
        where.student_id = { in: studentIds };
      } else if (user.role === "industry_supervisor") {
        const scope = await resolveIndustryScope(user.profileId);
        if (scope.industryIds.length === 0) {
          return sendSuccess(res, {
            data: [],
            pagination: { page, limit, total: 0, totalPages: 0 },
          });
        }
        where.internships = {
          OR: [
            { industry_id: { in: scope.industryIds } },
            ...(scope.companyNames.length > 0
              ? [{ company_name: { in: scope.companyNames } }]
              : []),
          ],
        };
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

      const missingIds = itrs.filter((r) => !r.students).map((r) => r.student_id);
      const fallbackProfiles = new Map<string, string>();
      if (missingIds.length > 0) {
        const profiles = await prisma.profiles.findMany({
          where: { id: { in: missingIds } },
          select: { id: true, full_name: true },
        });
        profiles.forEach((p) => {
          if (p.full_name) fallbackProfiles.set(p.id, p.full_name);
        });
      }

      const data = itrs.map((itr) => ({
        id: itr.id,
        internshipId: itr.internship_id,
        studentId: itr.student_id,
        studentName:
          itr.students?.profiles?.full_name ||
          fallbackProfiles.get(itr.student_id) ||
          "Student",
        internshipTitle:
          itr.internships?.internship_title || itr.internships?.title || "Internship",
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
   * Retrieve single ITR details with ownership checks.
   */
  static async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

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

      if (user.role === "student") {
        const studentIds = [user.studentId, user.profileId].filter(
          (v): v is string => Boolean(v)
        );
        if (!studentIds.includes(itr.student_id)) {
          throw ApiError.forbidden("Access denied: you can only view your own ITR");
        }
      } else if (user.role === "industry_supervisor") {
        const scope = await resolveIndustryScope(user.profileId);
        const matchesIndustryId = scope.industryIds.includes(itr.internships.industry_id);
        const matchesCompany =
          Boolean(itr.internships.company_name) &&
          scope.companyNames.includes(itr.internships.company_name!);
        if (!matchesIndustryId && !matchesCompany) {
          throw ApiError.forbidden("Access denied: ITR belongs to another organization");
        }
      }

      return sendSuccess(res, itr);
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /itr/:id/review
   * Review an ITR submission, assign optional rubric scores and verify.
   */
  static async review(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const id = typeof req.params.id === "string" ? req.params.id : String(req.params.id || "");
      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid ITR UUID");
      }

      const existing = await prisma.itrs.findUnique({
        where: { id },
        include: {
          internships: {
            select: { id: true, industry_id: true, company_name: true, student_id: true },
          },
        },
      });
      if (!existing) {
        throw ApiError.notFound("ITR not found");
      }

      if (user.role === "industry_supervisor") {
        const scope = await resolveIndustryScope(user.profileId);
        const matchesIndustryId = scope.industryIds.includes(existing.internships.industry_id);
        const matchesCompany =
          Boolean(existing.internships.company_name) &&
          scope.companyNames.includes(existing.internships.company_name!);
        if (!matchesIndustryId && !matchesCompany) {
          throw ApiError.forbidden(
            "Access denied: ITR does not belong to your assigned organization"
          );
        }
      }

      const parsed = reviewItrSchema.parse(req.body);
      const now = new Date();

      const updated = await prisma.itrs.update({
        where: { id },
        data: {
          status: parsed.status,
          remarks: parsed.remarks,
          reviewer_name: parsed.reviewer_name || user.email || "Reviewer",
          reviewer_id: user.profileId,
          reviewed_at: now,
          verified_at: parsed.status === "approved" ? now : undefined,
        },
      });

      const hasAllScores =
        parsed.technical_score !== undefined &&
        parsed.work_quality_score !== undefined &&
        parsed.punctuality_score !== undefined &&
        parsed.presentation_score !== undefined;

      if (hasAllScores) {
        const totalScore =
          parsed.technical_score! +
          parsed.work_quality_score! +
          parsed.punctuality_score! +
          parsed.presentation_score!;
        let grade = "F";
        if (totalScore >= 90) grade = "A+";
        else if (totalScore >= 80) grade = "A";
        else if (totalScore >= 70) grade = "B";
        else if (totalScore >= 60) grade = "C";
        else if (totalScore >= 50) grade = "D";

        const studentRow = await prisma.students.findFirst({
          where: {
            OR: [{ id: existing.student_id }, { user_id: existing.student_id }],
          },
          select: { id: true },
        });
        const existingEval = await prisma.evaluations.findFirst({
          where: { internship_id: existing.internship_id },
          orderBy: { created_at: "desc" },
          select: { id: true },
        });

        if (existingEval) {
          await prisma.evaluations.update({
            where: { id: existingEval.id },
            data: {
              evaluator_id: user.profileId,
              score: totalScore,
              marks: totalScore,
              total_score: totalScore,
              grade,
              remarks: parsed.remarks || "ITR evaluation recorded",
              status: "submitted",
              submitted_at: now,
              updated_at: now,
            },
          });
        } else {
          await prisma.evaluations.create({
            data: {
              internship_id: existing.internship_id,
              student_id: studentRow?.id ?? null,
              industry_id: existing.internships.industry_id,
              evaluator_id: user.profileId,
              score: totalScore,
              marks: totalScore,
              total_score: totalScore,
              grade,
              remarks: parsed.remarks || "ITR evaluation recorded",
              status: "submitted",
              submitted_at: now,
            },
          });
        }
      }

      // Trigger student notification on status update
      try {
        const studentRow = await prisma.students.findFirst({
          where: {
            OR: [{ id: existing.student_id }, { user_id: existing.student_id }],
          },
          select: { user_id: true, id: true },
        });
        const recipientUserId = studentRow?.user_id || existing.student_id;

        let notifType: any = "system";
        if (parsed.status === "approved") notifType = "itr_approved";
        else if (parsed.status === "rejected") notifType = "itr_rejected";
        else if (parsed.status === "changes_requested") notifType = "itr_changes_requested";

        await prisma.notifications.create({
          data: {
            recipient_id: recipientUserId,
            type: notifType,
            title:
              parsed.status === "approved"
                ? "ITR Approved"
                : parsed.status === "rejected"
                ? "ITR Rejected"
                : "ITR Changes Requested",
            message: `Your ITR for ${
              existing.internships.company_name || "your internship"
            } has been updated to '${parsed.status}'. ${
              parsed.remarks ? `Remarks: ${parsed.remarks}` : ""
            }`,
            reference_type: "itr",
            reference_id: existing.id,
          },
        });
      } catch (notifErr) {
        console.warn("Failed to create student notification for ITR review:", notifErr);
      }

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

  /**
   * POST /itr/:id/submit
   * Submit or resubmit an ITR with strict validation and reviewer notifications.
   */
  static async submit(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const id = typeof req.params.id === "string" ? req.params.id : String(req.params.id || "");
      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid ITR UUID");
      }

      const existing = await prisma.itrs.findUnique({
        where: { id },
        include: {
          internships: {
            select: { id: true, industry_id: true, company_name: true, student_id: true },
          },
        },
      });

      if (!existing) {
        throw ApiError.notFound("ITR not found");
      }

      // Verification of student ownership
      if (user.role === "student") {
        const studentIds = [user.studentId, user.profileId].filter(
          (v): v is string => Boolean(v)
        );
        if (!studentIds.includes(existing.student_id)) {
          throw ApiError.forbidden("Access denied: you can only submit your own ITR");
        }
      }

      const {
        content,
        workDone,
        technologiesUsed,
        keyLearnings,
        challengesFaced,
        projectZipPath,
        presentationPath,
        certificateUrl,
      } = req.body;

      const effectiveContent = (content || workDone || "").trim();
      if (!effectiveContent || effectiveContent.length < 20) {
        throw ApiError.badRequest(
          "Work done description is required and must be at least 20 characters long."
        );
      }

      // Validate file formats if provided
      if (projectZipPath && typeof projectZipPath === "string") {
        const cleanPath = projectZipPath.split("?")[0].toLowerCase();
        if (!cleanPath.endsWith(".zip")) {
          throw ApiError.badRequest("Project file must be a .zip archive.");
        }
      }

      if (presentationPath && typeof presentationPath === "string") {
        const cleanPath = presentationPath.split("?")[0].toLowerCase();
        if (!cleanPath.endsWith(".ppt") && !cleanPath.endsWith(".pptx")) {
          throw ApiError.badRequest("Presentation must be a .ppt or .pptx file.");
        }
      }

      if (certificateUrl && typeof certificateUrl === "string") {
        const cleanPath = certificateUrl.split("?")[0].toLowerCase();
        const validCert = [".pdf", ".png", ".jpg", ".jpeg"].some((ext) => cleanPath.endsWith(ext));
        if (!validCert) {
          throw ApiError.badRequest(
            "Certificate must be a PDF or image file (.pdf, .png, .jpg, .jpeg)."
          );
        }
      }

      const now = new Date();
      const updated = await prisma.itrs.update({
        where: { id },
        data: {
          status: "submitted",
          content: effectiveContent,
          work_done: (workDone || effectiveContent).trim(),
          technologies_used: technologiesUsed || existing.technologies_used,
          key_learnings: keyLearnings || existing.key_learnings,
          challenges_faced: challengesFaced || existing.challenges_faced,
          project_zip_path: projectZipPath || existing.project_zip_path,
          presentation_path: presentationPath || existing.presentation_path,
          document_path: certificateUrl || existing.document_path,
          submitted_at: now,
          updated_at: now,
        },
      });

      // Notify industry supervisor / reviewer on resubmission or submission
      try {
        const supervisors = await prisma.industry_users.findMany({
          where: { industry_id: existing.internships.industry_id },
          select: { user_id: true },
        });

        for (const sup of supervisors) {
          await prisma.notifications.create({
            data: {
              recipient_id: sup.user_id,
              type: "itr_submitted",
              title: "ITR Submitted for Review",
              message: `An ITR has been submitted/resubmitted for ${
                existing.internships.company_name || "your company"
              } and requires review.`,
              reference_type: "itr",
              reference_id: existing.id,
            },
          });
        }
      } catch (notifErr) {
        console.warn("Failed to notify supervisors of ITR submission:", notifErr);
      }

      return sendSuccess(res, {
        id: updated.id,
        status: updated.status,
        submittedAt: updated.submitted_at,
        message: "ITR submitted successfully",
      });
    } catch (error) {
      next(error);
    }
  }
}
