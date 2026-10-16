import { Request, Response, NextFunction } from "express";

function sanitizeData(data: any): any {
  if (!data || typeof data !== "object") return data;

  if (Array.isArray(data)) {
    return data.map(sanitizeData);
  }

  const sensitiveKeys = [
    "password",
    "token",
    "access_token",
    "authorization",
    "secret",
    "key",
    "cookie",
  ];

  const sanitized: Record<string, any> = {};
  for (const [key, value] of Object.entries(data)) {
    if (sensitiveKeys.some((k) => key.toLowerCase().includes(k))) {
      sanitized[key] = "[REDACTED]";
    } else if (typeof value === "object" && value !== null) {
      sanitized[key] = sanitizeData(value);
    } else {
      sanitized[key] = value;
    }
  }

  return sanitized;
}

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();
  const { method, originalUrl } = req;

  res.on("finish", () => {
    const duration = Date.now() - start;
    const statusCode = res.statusCode;
    const timestamp = new Date().toISOString();

    const color =
      statusCode >= 500
        ? "\x1b[31m" // red
        : statusCode >= 400
        ? "\x1b[33m" // yellow
        : statusCode >= 300
        ? "\x1b[36m" // cyan
        : "\x1b[32m"; // green

    console.log(
      `[${timestamp}] ${method} ${originalUrl} ${color}${statusCode}\x1b[0m ${duration}ms`
    );
  });

  next();
}
