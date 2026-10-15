import "dotenv/config";
import { PrismaClient } from "../../generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  console.warn("WARNING: DATABASE_URL environment variable is not defined.");
}

const adapter = new PrismaPg({
  connectionString: connectionString || "",
});

export const prisma = new PrismaClient({
  adapter,
  log: process.env.NODE_ENV === "development" ? ["warn", "error"] : ["error"],
});

export async function disconnectPrisma(): Promise<void> {
  try {
    await prisma.$disconnect();
    console.log("Prisma disconnected gracefully.");
  } catch (err) {
    console.error("Error during Prisma disconnect:", err);
  }
}
