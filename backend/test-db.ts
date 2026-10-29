import "dotenv/config";
import { PrismaClient } from "./generated/prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const adapter = new PrismaPg({
  connectionString: process.env.DATABASE_URL!,
});

const prisma = new PrismaClient({ adapter });

async function main() {
  const result = await prisma.$queryRaw`
    SELECT current_database() AS database_name
  `;

  console.log("Database connection successful!");
  console.log(result);
}

main()
  .catch((error) => {
    console.error("Database test failed:", error);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });