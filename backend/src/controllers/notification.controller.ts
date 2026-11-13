import { Request, Response, NextFunction } from "express";
import { prisma } from "../config/db";
import { ApiError, sendSuccess } from "../utils/response";
import { parsePagination, isValidUuid } from "../utils/validators";

export class NotificationController {
  /**
   * GET /notifications
   * List notifications for authenticated user.
   */
  static async getNotifications(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const { page, limit, skip } = parsePagination(req.query);
      const recipientIds = [user.profileId, user.id].filter(Boolean);

      const [total, notifications, unreadCount] = await Promise.all([
        prisma.notifications.count({
          where: { recipient_id: { in: recipientIds } },
        }),
        prisma.notifications.findMany({
          where: { recipient_id: { in: recipientIds } },
          skip,
          take: limit,
          orderBy: { created_at: "desc" },
        }),
        prisma.notifications.count({
          where: { recipient_id: { in: recipientIds }, is_read: false },
        }),
      ]);

      return sendSuccess(res, {
        notifications,
        unreadCount,
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
   * GET /notifications/unread-count
   * Get count of unread notifications for quick badge display.
   */
  static async getUnreadCount(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const recipientIds = [user.profileId, user.id].filter(Boolean);
      const unreadCount = await prisma.notifications.count({
        where: { recipient_id: { in: recipientIds }, is_read: false },
      });

      return sendSuccess(res, { unreadCount });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /notifications/:id/read
   * Mark a notification as read.
   */
  static async markAsRead(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const id = typeof req.params.id === "string" ? req.params.id : String(req.params.id || "");
      if (!isValidUuid(id)) {
        throw ApiError.badRequest("Invalid notification UUID");
      }

      const notif = await prisma.notifications.findUnique({
        where: { id },
      });
      if (!notif) {
        throw ApiError.notFound("Notification not found");
      }

      if (notif.recipient_id !== user.profileId && notif.recipient_id !== user.id) {
        throw ApiError.forbidden("Access denied: notification does not belong to you");
      }

      const updated = await prisma.notifications.update({
        where: { id },
        data: {
          is_read: true,
          read_at: new Date(),
        },
      });

      return sendSuccess(res, updated);
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /notifications/read-all
   * Mark all notifications as read for current user.
   */
  static async markAllAsRead(req: Request, res: Response, next: NextFunction) {
    try {
      const user = req.user;
      if (!user) throw ApiError.unauthorized();

      const recipientIds = [user.profileId, user.id].filter(Boolean);

      const result = await prisma.notifications.updateMany({
        where: {
          recipient_id: { in: recipientIds },
          is_read: false,
        },
        data: {
          is_read: true,
          read_at: new Date(),
        },
      });

      return sendSuccess(res, {
        markedCount: result.count,
        message: "All notifications marked as read",
      });
    } catch (error) {
      next(error);
    }
  }
}

