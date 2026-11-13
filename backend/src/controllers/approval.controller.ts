import { Request, Response, NextFunction } from "express";
import { internship_status } from "../../generated/prisma/client";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import {
  isValidUuid,
  parsePagination,
  createApprovalReviewSchema,
} from "../utils/validators";

export class ApprovalController {
  /**
   * GET /approvals
   * List all approval reviews with filtering by status, stage, or internship.
   */
  static async getAll(req: Request, res: Response, next: NextFunction) {
    try {
      const { page, limit, skip } = parsePagination(req.query);
      const { status, stage, internship_id } = req.query;

      const where: any = {};

      if (typeof status === "string" && status.trim()) {
        where.status = status.trim();
      }

      if (typeof stage === "string" && stage.trim()) {
        where.review_stage = stage.trim();
      }

      if (typeof internship_id === "string" && internship_id.trim()) {
        if (!isValidUuid(internship_id)) {
          throw ApiError.badRequest("Invalid internship_id parameter: must be a valid UUID");
        }
        where.internship_id = internship_id.trim();
      }

      const [total, reviews] = await Promise.all([
        prisma.approval_reviews.count({ where }),
        prisma.approval_reviews.findMany({
          where,
          skip,
          take: limit,
          orderBy: { created_at: "desc" },
          include: {
            internships: {
              select: {
                id: true,
                internship_title: true,
                company_name: true,
                status: true,
                students: {
                  select: {
                    id: true,
                    roll_number: true,
                    department: true,
                    profiles: {
                      select: {
                        full_name: true,
                        email: true,
                      },
                    },
                  },
                },
              },
            },
            profiles: {
              select: {
                id: true,
                full_name: true,
                role: true,
                email: true,
              },
            },
          },
        }),
      ]);

      const formatted = reviews.map((item) => ({
        id: item.id,
        internshipId: item.internship_id,
        internshipTitle: item.internships?.internship_title || "Untitled Internship",
        companyName: item.internships?.company_name || "N/A",
        internshipStatus: item.internships?.status,
        studentId: item.internships?.students?.id,
        studentName: item.internships?.students?.profiles?.full_name || "Unknown Student",
        rollNumber: item.internships?.students?.roll_number,
        department: item.internships?.students?.department,
        reviewerId: item.reviewer_id,
        reviewerName: item.profiles?.full_name || "Reviewer",
        reviewerRole: item.profiles?.role,
        reviewStage: item.review_stage,
        status: item.status,
        remarks: item.remarks,
        createdAt: item.created_at,
      }));

      return sendSuccess(res, formatted, {
        count: formatted.length,
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit) || 1,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /approvals/:id
   * Get approval review details by review ID.
   */
  static async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const id = typeof req.params.id === "string" ? req.params.id : req.params.id?.[0] || "";

      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid approval ID: must be a valid UUID");
      }

      const review = await prisma.approval_reviews.findUnique({
        where: { id },
        include: {
          internships: {
            include: {
              students: {
                include: {
                  profiles: {
                    select: {
                      full_name: true,
                      email: true,
                      phone_number: true,
                    },
                  },
                },
              },
              industries: true,
            },
          },
          profiles: {
            select: {
              id: true,
              full_name: true,
              role: true,
            },
          },
        },
      });

      if (!review) {
        throw ApiError.notFound(`Approval review with ID '${id}' was not found`);
      }

      return sendSuccess(res, review);
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /approvals/:internshipId/review
   * Submit an approval review (faculty or T&P) for an internship.
   */
  static async createReview(req: Request, res: Response, next: NextFunction) {
    try {
      const internshipId =
        typeof req.params.internshipId === "string"
          ? req.params.internshipId
          : req.params.internshipId?.[0] || "";

      if (!isValidUuid(internshipId)) {
        throw ApiError.badRequest("Invalid internship ID: must be a valid UUID");
      }

      if (!req.user) {
        throw ApiError.unauthorized("Authentication required to review internship");
      }

      const validated = createApprovalReviewSchema.parse(req.body);

      if (validated.status === "rejected" && (!validated.remarks || !validated.remarks.trim())) {
        throw ApiError.badRequest("Remarks are required when rejecting an application");
      }

      const internship = await prisma.internships.findUnique({
        where: { id: internshipId },
        select: { id: true, status: true, student_id: true },
      });

      if (!internship) {
        throw ApiError.notFound(`Internship with ID '${internshipId}' was not found`);
      }

      // Determine stage strictly from role (only admin may specify stage explicitly)
      let reviewStage = "faculty";
      if (req.user.role === "tp_officer") {
        reviewStage = "tp_admin";
      } else if (req.user.role === "admin" && validated.stage) {
        reviewStage = validated.stage;
      }

      // Normalize status against approval_reviews_status_check ('pending','under_review','approved','rejected')
      const normalizedReviewStatus =
        validated.status === "changes_requested" ? "under_review" : validated.status;

      // Keep internship status synchronized when approved/rejected/under_review
      let nextInternshipStatus: internship_status | null = null;
      if (normalizedReviewStatus === "rejected") {
        nextInternshipStatus = "rejected";
      } else if (normalizedReviewStatus === "under_review") {
        nextInternshipStatus = "under_review";
      } else if (reviewStage === "tp_admin" && normalizedReviewStatus === "approved") {
        nextInternshipStatus = "active";
      } else if (reviewStage === "faculty" && normalizedReviewStatus === "approved") {
        nextInternshipStatus = "approved";
      }

      // Execute in transaction: record review and update internship status
      const [newReview] = await prisma.$transaction([
        prisma.approval_reviews.create({
          data: {
            internship_id: internshipId,
            reviewer_id: req.user.profileId,
            review_stage: reviewStage,
            status: normalizedReviewStatus,
            remarks: validated.remarks?.trim() || null,
          },
        }),
        ...(nextInternshipStatus
          ? [
              prisma.internships.update({
                where: { id: internshipId },
                data: {
                  status: nextInternshipStatus,
                  updated_at: new Date(),
                },
              }),
            ]
          : []),
      ]);

      return sendSuccess(res, newReview, {
        statusCode: 201,
        message: `Internship review successfully recorded as '${validated.status}'`,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /approvals/stats/summary
   * Aggregated approval counts for Faculty and T&P dashboard.
   */
  static async getStats(_req: Request, res: Response, next: NextFunction) {
    try {
      const [
        totalReviews,
        facultyPending,
        tpPending,
        approvedTotal,
        rejectedTotal,
      ] = await Promise.all([
        prisma.approval_reviews.count(),
        prisma.approval_reviews.count({
          where: { review_stage: "faculty", status: "pending" },
        }),
        prisma.approval_reviews.count({
          where: { review_stage: "tp_admin", status: "pending" },
        }),
        prisma.approval_reviews.count({
          where: { status: "approved" },
        }),
        prisma.approval_reviews.count({
          where: { status: "rejected" },
        }),
      ]);

      return sendSuccess(res, {
        totalReviews,
        facultyPending,
        tpPending,
        approvedTotal,
        rejectedTotal,
      });
    } catch (error) {
      next(error);
    }
  }
}

