import { Request, Response, NextFunction } from "express";
import { Prisma } from "../../generated/prisma/client";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import {
  isValidUuid,
  createPlacementNoticeSchema,
  updatePlacementNoticeSchema,
  createTpFaqSchema,
  updateTpFaqSchema,
  createStudentQuerySchema,
  createQueryReplySchema,
  updateQueryStatusSchema,
  createNocRequestSchema,
  reviewNocRequestSchema,
} from "../utils/validators";

function isStaffOrTp(role?: string): boolean {
  return role === "tp_officer" || role === "admin";
}

function defaultTitleFor(companyName: string, opportunityType: string): string {
  const labelMap: Record<string, string> = {
    internship: "Internship Opportunity",
    full_time: "Full-Time Job Opening",
    internship_ppo: "Internship + PPO Opportunity",
    campus_recruitment: "Campus Recruitment Drive",
    other: "Placement Notice",
  };
  return `${companyName.trim()} - ${labelMap[opportunityType] || "Placement Notice"}`;
}

function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length >= 2);
}

const STOP_WORDS = new Set([
  "the", "is", "are", "for", "and", "can", "how", "what", "when", "where",
  "why", "will", "this", "that", "with", "from", "have", "has", "does",
  "kya", "hai", "liye", "kaise", "hoga", "karna", "mein", "ko", "ka", "ki",
]);

function scoreFaqRelevance(
  faq: {
    question: string;
    answer: string;
    category: string;
    keywords?: string[] | null;
    usage_count?: number;
  },
  queryText: string,
  category?: string
): number {
  const qLower = queryText.toLowerCase().trim();
  if (!qLower) return 0;

  const queryTokens = tokenize(qLower).filter((t) => !STOP_WORDS.has(t));
  if (queryTokens.length === 0) return 0;

  const faqQuestion = (faq.question || "").toLowerCase();
  const faqAnswer = (faq.answer || "").toLowerCase();
  const faqKeywords = (faq.keywords || []).map((k) => k.toLowerCase());

  let score = 0;

  if (faqQuestion.includes(qLower)) score += 10;

  for (const token of queryTokens) {
    if (faqKeywords.some((k) => k === token || k.includes(token) || token.includes(k))) {
      score += 4;
    }
    if (faqQuestion.includes(token)) {
      score += 3;
    } else if (faqAnswer.includes(token)) {
      score += 1.5;
    }
  }

  if (category && faq.category.toLowerCase() === category.toLowerCase()) {
    score += 2;
  }

  if ((faq.usage_count || 0) > 0) {
    score += Math.min(2, (faq.usage_count || 0) * 0.1);
  }

  return score;
}

export class PlacementController {
  static async getAvailableBranches(_req: Request, res: Response, next: NextFunction) {
    try {
      const rows = await prisma.$queryRaw<{ branches: string[] }[]>`
        SELECT public.get_available_branches() AS branches
      `;
      return sendSuccess(res, rows[0]?.branches || []);
    } catch (error) {
      next(error);
    }
  }

  static async getDashboardSummary(_req: Request, res: Response, next: NextFunction) {
    try {
      const rows = await prisma.$queryRaw<{ summary: any }[]>`
        SELECT public.get_tp_dashboard_summary() AS summary
      `;
      return sendSuccess(res, rows[0]?.summary || {});
    } catch (error) {
      next(error);
    }
  }

  static async getNotices(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const { status, opportunity_type, branch, company, search } = req.query;
      const isPrivileged = ["tp_officer", "admin", "faculty_mentor"].includes(user.role);

      let studentBranch: string | null = user.department || null;
      if (!isPrivileged && !studentBranch) {
        const profRows = await prisma.$queryRaw<{ branch_name: string | null }[]>`
          SELECT COALESCE(NULLIF(TRIM(p.branch), ''), NULLIF(TRIM(p.department), ''), s.department) AS branch_name
          FROM public.profiles p
          LEFT JOIN public.students s ON s.user_id = p.id
          WHERE p.id = ${user.profileId}::uuid
          LIMIT 1
        `;
        studentBranch = profRows[0]?.branch_name || null;
      }

      const conditions: Prisma.Sql[] = [Prisma.sql`1 = 1`];

      if (!isPrivileged) {
        conditions.push(
          Prisma.sql`public.branch_matches(pn.target_branches, pn.is_all_branches, ${studentBranch})`
        );
      }

      if (typeof status === "string" && status.trim() && status !== "all") {
        conditions.push(Prisma.sql`pn.status = ${status.trim()}`);
      }

      if (typeof opportunity_type === "string" && opportunity_type.trim() && opportunity_type !== "all") {
        conditions.push(Prisma.sql`pn.opportunity_type = ${opportunity_type.trim()}`);
      }

      if (typeof branch === "string" && branch.trim() && branch !== "all") {
        conditions.push(
          Prisma.sql`public.branch_matches(pn.target_branches, pn.is_all_branches, ${branch.trim()})`
        );
      }

      if (typeof company === "string" && company.trim()) {
        conditions.push(Prisma.sql`pn.company_name ILIKE ${"%" + company.trim() + "%"}`);
      }

      if (typeof search === "string" && search.trim()) {
        const q = "%" + search.trim() + "%";
        conditions.push(
          Prisma.sql`(pn.company_name ILIKE ${q} OR pn.title ILIKE ${q} OR COALESCE(pn.description, '') ILIKE ${q} OR COALESCE(pn.eligibility, '') ILIKE ${q})`
        );
      }

      const whereClause = Prisma.join(conditions, " AND ");

      const notices = await prisma.$queryRaw<any[]>`
        SELECT
          pn.*,
          EXISTS (
            SELECT 1 FROM public.placement_notice_reads r
            WHERE r.notice_id = pn.id AND r.user_id = ${user.profileId}::uuid
          ) AS is_read,
          COALESCE(
            (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'id', a.id,
                  'notice_id', a.notice_id,
                  'file_name', a.file_name,
                  'file_path', a.file_path,
                  'file_type', a.file_type,
                  'mime_type', a.mime_type,
                  'file_size', a.file_size,
                  'created_at', a.created_at
                )
                ORDER BY a.created_at ASC
              )
              FROM public.placement_notice_attachments a
              WHERE a.notice_id = pn.id
            ),
            '[]'::jsonb
          ) AS attachments
        FROM public.placement_notices pn
        WHERE ${whereClause}
        ORDER BY pn.created_at DESC
      `;

      return sendSuccess(res, notices);
    } catch (error) {
      next(error);
    }
  }

  static async getNoticeById(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const id = String(req.params.id || "");
      if (!isValidUuid(id)) throw ApiError.badRequest("Invalid notice UUID");

      const rows = await prisma.$queryRaw<any[]>`
        SELECT
          pn.*,
          EXISTS (
            SELECT 1 FROM public.placement_notice_reads r
            WHERE r.notice_id = pn.id AND r.user_id = ${user.profileId}::uuid
          ) AS is_read,
          COALESCE(
            (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'id', a.id,
                  'notice_id', a.notice_id,
                  'file_name', a.file_name,
                  'file_path', a.file_path,
                  'file_type', a.file_type,
                  'mime_type', a.mime_type,
                  'file_size', a.file_size,
                  'created_at', a.created_at
                )
                ORDER BY a.created_at ASC
              )
              FROM public.placement_notice_attachments a
              WHERE a.notice_id = pn.id
            ),
            '[]'::jsonb
          ) AS attachments
        FROM public.placement_notices pn
        WHERE pn.id = ${id}::uuid
        LIMIT 1
      `;

      if (rows.length === 0) throw ApiError.notFound("Placement notice not found");
      const notice = rows[0];

      if (!["tp_officer", "admin", "faculty_mentor"].includes(user.role)) {
        const branchRows = await prisma.$queryRaw<{ allowed: boolean }[]>`
          SELECT public.branch_matches(
            ${notice.target_branches}::text[],
            ${Boolean(notice.is_all_branches)},
            (
              SELECT COALESCE(NULLIF(TRIM(p.branch), ''), NULLIF(TRIM(p.department), ''), s.department)
              FROM public.profiles p
              LEFT JOIN public.students s ON s.user_id = p.id
              WHERE p.id = ${user.profileId}::uuid
              LIMIT 1
            )
          ) AS allowed
        `;
        if (!branchRows[0]?.allowed) {
          throw ApiError.forbidden("This notice is not targeted to your branch");
        }
      }

      return sendSuccess(res, notice);
    } catch (error) {
      next(error);
    }
  }

  static async createNotice(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const parsed = createPlacementNoticeSchema.parse(req.body);
      const effectiveTitle =
        parsed.title && parsed.title.trim().length > 0
          ? parsed.title.trim()
          : defaultTitleFor(parsed.company_name, parsed.opportunity_type);

      if (
        !parsed.is_all_branches &&
        (!parsed.target_branches || parsed.target_branches.length === 0)
      ) {
        throw ApiError.badRequest("Select at least one branch or enable All Branches");
      }

      const deadlineVal = parsed.application_deadline ? new Date(parsed.application_deadline) : null;
      const driveDateVal = parsed.recruitment_date ? new Date(parsed.recruitment_date) : null;

      const rows = await prisma.$queryRaw<any[]>`
        INSERT INTO public.placement_notices (
          industry_id, company_name, opportunity_type, title, description,
          eligibility, recruitment_process, additional_notes, application_link,
          application_deadline, recruitment_date, is_all_branches, target_branches,
          status, notify_students, created_by, created_at, updated_at
        ) VALUES (
          ${parsed.industry_id || null}::uuid,
          ${parsed.company_name.trim()},
          ${parsed.opportunity_type},
          ${effectiveTitle},
          ${parsed.description || null},
          ${parsed.eligibility || null},
          ${parsed.recruitment_process || null},
          ${parsed.additional_notes || null},
          ${parsed.application_link || null},
          ${deadlineVal},
          ${driveDateVal},
          ${parsed.is_all_branches},
          ${parsed.target_branches}::text[],
          ${parsed.status},
          ${parsed.notify_students},
          ${user.profileId}::uuid,
          NOW(),
          NOW()
        )
        RETURNING *
      `;

      return sendSuccess(res, rows[0], { statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  static async updateNotice(req: Request, res: Response, next: NextFunction) {
    try {
      const id = String(req.params.id || "");
      if (!isValidUuid(id)) throw ApiError.badRequest("Invalid notice UUID");

      const parsed = updatePlacementNoticeSchema.parse(req.body);

      const existingRows = await prisma.$queryRaw<any[]>`
        SELECT * FROM public.placement_notices WHERE id = ${id}::uuid LIMIT 1
      `;
      if (existingRows.length === 0) throw ApiError.notFound("Notice not found");
      const current = existingRows[0];

      const companyName = parsed.company_name?.trim() || current.company_name;
      const oppType = parsed.opportunity_type || current.opportunity_type;
      const title =
        parsed.title !== undefined
          ? parsed.title?.trim() || defaultTitleFor(companyName, oppType)
          : current.title;

      const rows = await prisma.$queryRaw<any[]>`
        UPDATE public.placement_notices
        SET
          company_name = ${companyName},
          opportunity_type = ${oppType},
          title = ${title},
          description = ${parsed.description !== undefined ? parsed.description : current.description},
          eligibility = ${parsed.eligibility !== undefined ? parsed.eligibility : current.eligibility},
          recruitment_process = ${parsed.recruitment_process !== undefined ? parsed.recruitment_process : current.recruitment_process},
          additional_notes = ${parsed.additional_notes !== undefined ? parsed.additional_notes : current.additional_notes},
          application_link = ${parsed.application_link !== undefined ? parsed.application_link : current.application_link},
          application_deadline = ${parsed.application_deadline !== undefined ? (parsed.application_deadline ? new Date(parsed.application_deadline) : null) : current.application_deadline},
          recruitment_date = ${parsed.recruitment_date !== undefined ? (parsed.recruitment_date ? new Date(parsed.recruitment_date) : null) : current.recruitment_date},
          is_all_branches = ${parsed.is_all_branches !== undefined ? parsed.is_all_branches : current.is_all_branches},
          target_branches = ${parsed.target_branches !== undefined ? parsed.target_branches : current.target_branches}::text[],
          status = ${parsed.status || current.status},
          notify_students = ${parsed.notify_students !== undefined ? parsed.notify_students : current.notify_students},
          updated_at = NOW()
        WHERE id = ${id}::uuid
        RETURNING *
      `;

      return sendSuccess(res, rows[0]);
    } catch (error) {
      next(error);
    }
  }

  static async deleteNotice(req: Request, res: Response, next: NextFunction) {
    try {
      const id = String(req.params.id || "");
      if (!isValidUuid(id)) throw ApiError.badRequest("Invalid notice UUID");

      await prisma.$executeRaw`
        DELETE FROM public.placement_notices WHERE id = ${id}::uuid
      `;

      return sendSuccess(res, { deleted: true });
    } catch (error) {
      next(error);
    }
  }

  static async markNoticeRead(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const id = String(req.params.id || "");
      if (!isValidUuid(id)) throw ApiError.badRequest("Invalid notice UUID");

      await prisma.$executeRaw`
        INSERT INTO public.placement_notice_reads (notice_id, user_id, read_at)
        VALUES (${id}::uuid, ${user.profileId}::uuid, NOW())
        ON CONFLICT (notice_id, user_id) DO NOTHING
      `;

      return sendSuccess(res, { read: true });
    } catch (error) {
      next(error);
    }
  }

  static async getFaqs(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const includeInactive = isStaffOrTp(user.role) && req.query.includeInactive === "true";
      const rows = await prisma.$queryRaw<any[]>`
        SELECT * FROM public.tp_faqs
        WHERE (${includeInactive} OR is_active = true)
        ORDER BY usage_count DESC, created_at DESC
      `;

      return sendSuccess(res, rows);
    } catch (error) {
      next(error);
    }
  }

  static async suggestFaqs(req: Request, res: Response, next: NextFunction) {
    try {
      const queryText = String(req.query.q || "").trim();
      const category = typeof req.query.category === "string" ? req.query.category : undefined;
      if (!queryText) {
        return sendSuccess(res, []);
      }

      const faqs = await prisma.$queryRaw<any[]>`
        SELECT * FROM public.tp_faqs WHERE is_active = true
      `;

      const ranked = faqs
        .map((faq) => ({
          ...faq,
          relevanceScore: scoreFaqRelevance(faq, queryText, category),
        }))
        .filter((f) => f.relevanceScore >= 2.5)
        .sort((a, b) => b.relevanceScore - a.relevanceScore)
        .slice(0, 5);

      return sendSuccess(res, ranked);
    } catch (error) {
      next(error);
    }
  }

  static async createFaq(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const parsed = createTpFaqSchema.parse(req.body);
      const rows = await prisma.$queryRaw<any[]>`
        INSERT INTO public.tp_faqs (
          category, question, answer, keywords, target_branches,
          is_all_branches, is_active, created_by, created_at, updated_at
        ) VALUES (
          ${parsed.category.trim()},
          ${parsed.question.trim()},
          ${parsed.answer.trim()},
          ${parsed.keywords}::text[],
          ${parsed.target_branches}::text[],
          ${parsed.is_all_branches},
          ${parsed.is_active},
          ${user.profileId}::uuid,
          NOW(),
          NOW()
        )
        RETURNING *
      `;

      return sendSuccess(res, rows[0], { statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  static async updateFaq(req: Request, res: Response, next: NextFunction) {
    try {
      const id = String(req.params.id || "");
      if (!isValidUuid(id)) throw ApiError.badRequest("Invalid FAQ UUID");

      const parsed = updateTpFaqSchema.parse(req.body);
      const existing = await prisma.$queryRaw<any[]>`
        SELECT * FROM public.tp_faqs WHERE id = ${id}::uuid LIMIT 1
      `;
      if (existing.length === 0) throw ApiError.notFound("FAQ not found");
      const current = existing[0];

      const rows = await prisma.$queryRaw<any[]>`
        UPDATE public.tp_faqs
        SET
          category = ${parsed.category?.trim() || current.category},
          question = ${parsed.question?.trim() || current.question},
          answer = ${parsed.answer?.trim() || current.answer},
          keywords = ${parsed.keywords ?? current.keywords}::text[],
          target_branches = ${parsed.target_branches ?? current.target_branches}::text[],
          is_all_branches = ${parsed.is_all_branches ?? current.is_all_branches},
          is_active = ${parsed.is_active ?? current.is_active},
          updated_at = NOW()
        WHERE id = ${id}::uuid
        RETURNING *
      `;

      return sendSuccess(res, rows[0]);
    } catch (error) {
      next(error);
    }
  }

  static async deleteFaq(req: Request, res: Response, next: NextFunction) {
    try {
      const id = String(req.params.id || "");
      if (!isValidUuid(id)) throw ApiError.badRequest("Invalid FAQ UUID");

      await prisma.$executeRaw`DELETE FROM public.tp_faqs WHERE id = ${id}::uuid`;
      return sendSuccess(res, { deleted: true });
    } catch (error) {
      next(error);
    }
  }

  static async getQueries(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const { status, category, branch, company, notice_id } = req.query;
      const conditions: Prisma.Sql[] = [Prisma.sql`1 = 1`];

      if (!isStaffOrTp(user.role)) {
        conditions.push(Prisma.sql`q.student_id = ${user.profileId}::uuid`);
      }

      if (typeof status === "string" && status.trim() && status !== "all") {
        conditions.push(Prisma.sql`q.status = ${status.trim()}`);
      }
      if (typeof category === "string" && category.trim() && category !== "all") {
        conditions.push(Prisma.sql`q.category = ${category.trim()}`);
      }
      if (typeof branch === "string" && branch.trim() && branch !== "all") {
        conditions.push(Prisma.sql`COALESCE(q.student_branch, '') ILIKE ${branch.trim()}`);
      }
      if (typeof company === "string" && company.trim()) {
        conditions.push(Prisma.sql`COALESCE(q.company_name, '') ILIKE ${"%" + company.trim() + "%"}`);
      }
      if (typeof notice_id === "string" && isValidUuid(notice_id)) {
        conditions.push(Prisma.sql`q.notice_id = ${notice_id}::uuid`);
      }

      const whereClause = Prisma.join(conditions, " AND ");
      const rows = await prisma.$queryRaw<any[]>`
        SELECT
          q.*,
          p.full_name AS student_name,
          p.enrollment_no AS student_roll_number,
          pn.title AS notice_title,
          COALESCE(
            (
              SELECT jsonb_agg(
                jsonb_build_object(
                  'id', r.id,
                  'query_id', r.query_id,
                  'sender_id', r.sender_id,
                  'sender_role', r.sender_role,
                  'sender_name', rp.full_name,
                  'message', r.message,
                  'created_at', r.created_at
                )
                ORDER BY r.created_at ASC
              )
              FROM public.student_query_replies r
              LEFT JOIN public.profiles rp ON rp.id = r.sender_id
              WHERE r.query_id = q.id
            ),
            '[]'::jsonb
          ) AS replies
        FROM public.student_queries q
        LEFT JOIN public.profiles p ON p.id = q.student_id
        LEFT JOIN public.placement_notices pn ON pn.id = q.notice_id
        WHERE ${whereClause}
        ORDER BY q.created_at DESC
      `;

      return sendSuccess(res, rows);
    } catch (error) {
      next(error);
    }
  }

  static async createQuery(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const parsed = createStudentQuerySchema.parse(req.body);
      const profRows = await prisma.$queryRaw<{ branch: string | null }[]>`
        SELECT COALESCE(NULLIF(TRIM(p.branch), ''), NULLIF(TRIM(p.department), ''), s.department) AS branch
        FROM public.profiles p
        LEFT JOIN public.students s ON s.user_id = p.id
        WHERE p.id = ${user.profileId}::uuid
        LIMIT 1
      `;

      let companyName = parsed.company_name?.trim() || null;
      if (!companyName && parsed.notice_id) {
        const noticeRows = await prisma.$queryRaw<{ company_name: string }[]>`
          SELECT company_name FROM public.placement_notices WHERE id = ${parsed.notice_id}::uuid LIMIT 1
        `;
        companyName = noticeRows[0]?.company_name || null;
      }

      const rows = await prisma.$queryRaw<any[]>`
        INSERT INTO public.student_queries (
          student_id, notice_id, company_name, student_branch, category, question,
          status, is_read_by_tp, created_at, updated_at
        ) VALUES (
          ${user.profileId}::uuid,
          ${parsed.notice_id || null}::uuid,
          ${companyName},
          ${profRows[0]?.branch || null},
          ${parsed.category.trim()},
          ${parsed.question.trim()},
          'open',
          false,
          NOW(),
          NOW()
        )
        RETURNING *
      `;

      return sendSuccess(res, rows[0], { statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  static async addQueryReply(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const id = String(req.params.id || "");
      if (!isValidUuid(id)) throw ApiError.badRequest("Invalid query UUID");

      const parsed = createQueryReplySchema.parse(req.body);

      const queryRows = await prisma.$queryRaw<any[]>`
        SELECT * FROM public.student_queries WHERE id = ${id}::uuid LIMIT 1
      `;
      if (queryRows.length === 0) throw ApiError.notFound("Query not found");
      const query = queryRows[0];

      if (!isStaffOrTp(user.role) && query.student_id !== user.profileId) {
        throw ApiError.forbidden("You do not have access to reply to this query");
      }

      const rows = await prisma.$queryRaw<any[]>`
        INSERT INTO public.student_query_replies (
          query_id, sender_id, sender_role, message, created_at
        ) VALUES (
          ${id}::uuid,
          ${user.profileId}::uuid,
          ${user.role},
          ${parsed.message.trim()},
          NOW()
        )
        RETURNING *
      `;

      return sendSuccess(res, rows[0], { statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  static async updateQueryStatus(req: Request, res: Response, next: NextFunction) {
    try {
      const id = String(req.params.id || "");
      if (!isValidUuid(id)) throw ApiError.badRequest("Invalid query UUID");

      const parsed = updateQueryStatusSchema.parse(req.body);
      const rows = await prisma.$queryRaw<any[]>`
        UPDATE public.student_queries
        SET status = ${parsed.status}, is_read_by_tp = true, updated_at = NOW()
        WHERE id = ${id}::uuid
        RETURNING *
      `;

      if (rows.length === 0) throw ApiError.notFound("Query not found");
      return sendSuccess(res, rows[0]);
    } catch (error) {
      next(error);
    }
  }

  static async getNocRequests(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const status = typeof req.query.status === "string" ? req.query.status.trim() : null;
      const isPrivileged = ["tp_officer", "admin", "faculty_mentor"].includes(user.role);

      const conditions: Prisma.Sql[] = [Prisma.sql`1 = 1`];
      if (!isPrivileged) {
        conditions.push(Prisma.sql`nr.student_id = ${user.profileId}::uuid`);
      }
      if (status && status !== "all") {
        conditions.push(Prisma.sql`nr.status = ${status}`);
      }

      const whereClause = Prisma.join(conditions, " AND ");
      const rows = await prisma.$queryRaw<any[]>`
        SELECT
          nr.*,
          p.full_name AS student_name,
          p.email AS student_email,
          COALESCE(nr.roll_number, p.enrollment_no, s.roll_number) AS effective_roll_number,
          COALESCE(nr.student_branch, p.branch, p.department, s.department) AS effective_branch,
          pn.title AS notice_title
        FROM public.noc_requests nr
        LEFT JOIN public.profiles p ON p.id = nr.student_id
        LEFT JOIN public.students s ON s.user_id = nr.student_id
        LEFT JOIN public.placement_notices pn ON pn.id = nr.notice_id
        WHERE ${whereClause}
        ORDER BY nr.created_at DESC
      `;

      return sendSuccess(res, rows);
    } catch (error) {
      next(error);
    }
  }

  static async createNocRequest(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const parsed = createNocRequestSchema.parse(req.body);
      const profRows = await prisma.$queryRaw<{ branch: string | null; roll: string | null }[]>`
        SELECT
          COALESCE(NULLIF(TRIM(p.branch), ''), NULLIF(TRIM(p.department), ''), s.department) AS branch,
          COALESCE(NULLIF(TRIM(p.enrollment_no), ''), s.roll_number) AS roll
        FROM public.profiles p
        LEFT JOIN public.students s ON s.user_id = p.id
        WHERE p.id = ${user.profileId}::uuid
        LIMIT 1
      `;

      const rows = await prisma.$queryRaw<any[]>`
        INSERT INTO public.noc_requests (
          student_id, internship_id, notice_id, company_name, opportunity_title,
          student_branch, roll_number, student_remarks, document_name, document_path,
          status, created_at, updated_at
        ) VALUES (
          ${user.profileId}::uuid,
          ${parsed.internship_id || null}::uuid,
          ${parsed.notice_id || null}::uuid,
          ${parsed.company_name.trim()},
          ${parsed.opportunity_title?.trim() || null},
          ${profRows[0]?.branch || null},
          ${profRows[0]?.roll || null},
          ${parsed.student_remarks?.trim() || null},
          ${parsed.document_name || null},
          ${parsed.document_path || null},
          'pending',
          NOW(),
          NOW()
        )
        RETURNING *
      `;

      return sendSuccess(res, rows[0], { statusCode: 201 });
    } catch (error) {
      next(error);
    }
  }

  static async reviewNocRequest(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const id = String(req.params.id || "");
      if (!isValidUuid(id)) throw ApiError.badRequest("Invalid NOC request UUID");

      const parsed = reviewNocRequestSchema.parse(req.body);
      if (parsed.status === "rejected" && !parsed.rejection_reason?.trim() && !parsed.tp_remarks?.trim()) {
        throw ApiError.badRequest("Rejection reason or remarks required when rejecting an NOC");
      }

      const rows = await prisma.$queryRaw<any[]>`
        UPDATE public.noc_requests
        SET
          status = ${parsed.status},
          tp_remarks = ${parsed.tp_remarks?.trim() || null},
          rejection_reason = ${parsed.status === "rejected" ? (parsed.rejection_reason?.trim() || parsed.tp_remarks?.trim() || null) : null},
          reviewed_by = ${user.profileId}::uuid,
          reviewed_at = NOW(),
          updated_at = NOW()
        WHERE id = ${id}::uuid
        RETURNING *
      `;

      if (rows.length === 0) throw ApiError.notFound("NOC request not found");
      return sendSuccess(res, rows[0]);
    } catch (error) {
      next(error);
    }
  }
}
