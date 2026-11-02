import { z } from "zod";

const UUID_REGEX =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

export function isValidUuid(id: string): boolean {
  return typeof id === "string" && UUID_REGEX.test(id.trim());
}

export function parsePagination(query: { page?: any; limit?: any }) {
  const page = Math.max(1, parseInt(query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(query.limit, 10) || 20));
  const skip = (page - 1) * limit;

  return { page, limit, skip };
}

export const updateStudentSchema = z.object({
  department: z.string().min(1).max(100).optional(),
  batch_year: z.number().int().min(2000).max(2100).optional().nullable(),
  full_name: z.string().min(1).max(150).optional(),
  phone_number: z.string().max(20).optional().nullable(),
  address: z.string().max(300).optional().nullable(),
  branch: z.string().max(100).optional().nullable(),
});

export const createInternshipSchema = z.object({
  student_id: z.string().regex(UUID_REGEX, "Invalid student_id UUID").optional(),
  industry_id: z.string().regex(UUID_REGEX, "Invalid industry_id UUID"),
  start_date: z.string().refine((val) => !isNaN(Date.parse(val)), "Invalid start_date"),
  end_date: z.string().refine((val) => !isNaN(Date.parse(val)), "Invalid end_date"),
  internship_title: z.string().min(2).max(150),
  company_name: z.string().min(1).max(150).optional(),
  title: z.string().max(150).optional(),
  mode: z.enum(["onsite", "remote", "hybrid"]).default("onsite"),
  description: z.string().max(1000).optional(),
});

export const updateInternshipSchema = z.object({
  internship_title: z.string().min(2).max(150).optional(),
  company_name: z.string().min(1).max(150).optional(),
  title: z.string().max(150).optional(),
  mode: z.enum(["onsite", "remote", "hybrid"]).optional(),
  description: z.string().max(1000).optional().nullable(),
  status: z
    .enum(["planned", "active", "completed", "cancelled"])
    .optional(),
  progress: z.number().int().min(0).max(100).optional(),
});

export const createProgressUpdateSchema = z.object({
  progress_percentage: z.number().int().min(0).max(100),
  update_text: z.string().min(3).max(1000),
});

export const createApprovalReviewSchema = z.object({
  status: z.enum(["approved", "rejected", "pending", "changes_requested"]),
  remarks: z.string().max(500).optional(),
});

export const createEvaluationSchema = z.object({
  internship_id: z.string().regex(UUID_REGEX, "Invalid internship_id UUID"),
  student_id: z.string().regex(UUID_REGEX, "Invalid student_id UUID").optional(),
  technical_score: z.number().min(0).max(25),
  work_quality_score: z.number().min(0).max(25),
  punctuality_score: z.number().min(0).max(25),
  presentation_score: z.number().min(0).max(25),
  remarks: z.string().max(1000).optional(),
  certificate_status: z.enum(["pending", "verified", "rejected"]).default("pending"),
});

export const reviewItrSchema = z.object({
  status: z.enum(["draft", "submitted", "under_review", "approved", "rejected"]),
  remarks: z.string().max(1000).optional(),
  reviewer_name: z.string().max(150).optional(),
  technical_score: z.number().min(0).max(25).optional(),
  work_quality_score: z.number().min(0).max(25).optional(),
  punctuality_score: z.number().min(0).max(25).optional(),
  presentation_score: z.number().min(0).max(25).optional(),
  certificate_status: z.enum(["pending", "verified", "rejected"]).optional(),
});

export const erpSyncGradesSchema = z.object({
  batch_year: z.number().int().min(2000).max(2100).optional(),
  department: z.string().max(100).optional(),
  export_format: z.enum(["json", "csv"]).default("json"),
});
