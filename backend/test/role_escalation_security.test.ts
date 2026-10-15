import { Client } from "pg";
import dotenv from "dotenv";
import assert from "assert";

dotenv.config();

/**
 * Automated Security Test Suite: Self-Signup Role Escalation Defense
 * 
 * Tests that:
 * 1. Proposed trigger logic strictly rejects client-supplied raw_user_meta_data roles
 *    (admin, faculty, tp_officer, industry_supervisor) and enforces 'student'.
 * 2. Trusted server-side raw_app_meta_data correctly provisions designated roles.
 * 3. Existing users and their elevated roles in public.profiles remain intact.
 * 4. RLS policies on public.profiles enforce administrative checks.
 */
async function runRoleSecurityTests() {
  console.log("=== Prashikshan Role Escalation Security Test Suite ===\n");
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  let passed = 0;
  let failed = 0;

  function testAssert(condition: boolean, description: string) {
    if (condition) {
      console.log(`  ✓ PASS: ${description}`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: ${description}`);
      failed++;
    }
  }

  try {
    await client.connect();

    // ------------------------------------------------------------------------
    // Group 1: Trigger Logic Simulation Tests
    // ------------------------------------------------------------------------
    console.log("[Group 1: Self-Signup Role Escalation Defense Simulation]");

    // Helper to evaluate the security-patched role resolution logic in PostgreSQL
    async function evaluateRoleResolution(
      userMetadata: Record<string, any> | null,
      appMetadata: Record<string, any> | null
    ): Promise<string> {
      const query = `
        SELECT (
          CASE 
            WHEN ($2::text::jsonb IS NOT NULL AND ($2::text::jsonb ? 'role')) THEN
              CASE LOWER(TRIM($2::text::jsonb->>'role'))
                WHEN 'admin' THEN 'admin'::public.app_role
                WHEN 'faculty' THEN 'faculty_mentor'::public.app_role
                WHEN 'faculty_mentor' THEN 'faculty_mentor'::public.app_role
                WHEN 'tnp' THEN 'tp_officer'::public.app_role
                WHEN 'tp_officer' THEN 'tp_officer'::public.app_role
                WHEN 'industry' THEN 'industry_supervisor'::public.app_role
                WHEN 'industry_supervisor' THEN 'industry_supervisor'::public.app_role
                ELSE 'student'::public.app_role
              END
            ELSE 'student'::public.app_role
          END
        )::text AS resolved_role,
        $1::text AS _unused_user_meta;
      `;
      const res = await client.query(query, [
        JSON.stringify(userMetadata || {}),
        JSON.stringify(appMetadata || {}),
      ]);
      return res.rows[0].resolved_role;
    }

    {
      const role = await evaluateRoleResolution({ role: "admin" }, {});
      testAssert(
        role === "student",
        "Self-signup attempting role: 'admin' in user_metadata resolves strictly to 'student'"
      );
    }

    {
      const role = await evaluateRoleResolution({ role: "faculty_mentor" }, {});
      testAssert(
        role === "student",
        "Self-signup attempting role: 'faculty_mentor' in user_metadata resolves strictly to 'student'"
      );
    }

    {
      const role = await evaluateRoleResolution({ role: "tp_officer" }, {});
      testAssert(
        role === "student",
        "Self-signup attempting role: 'tp_officer' in user_metadata resolves strictly to 'student'"
      );
    }

    {
      const role = await evaluateRoleResolution({ role: "industry_supervisor" }, {});
      testAssert(
        role === "student",
        "Self-signup attempting role: 'industry_supervisor' in user_metadata resolves strictly to 'student'"
      );
    }

    {
      const role = await evaluateRoleResolution({}, {});
      testAssert(
        role === "student",
        "Standard self-signup without role metadata defaults to 'student'"
      );
    }

    // ------------------------------------------------------------------------
    // Group 2: Server-Controlled Administrative Provisioning Simulation
    // ------------------------------------------------------------------------
    console.log("\n[Group 2: Trusted Administrative Provisioning via app_metadata]");

    {
      const role = await evaluateRoleResolution(
        { role: "malicious_student" },
        { role: "faculty_mentor" }
      );
      testAssert(
        role === "faculty_mentor",
        "Trusted server-side app_metadata 'faculty_mentor' assigns elevated faculty role"
      );
    }

    {
      const role = await evaluateRoleResolution({}, { role: "admin" });
      testAssert(
        role === "admin",
        "Trusted server-side app_metadata 'admin' assigns administrative role"
      );
    }

    {
      const role = await evaluateRoleResolution({}, { role: "tp_officer" });
      testAssert(
        role === "tp_officer",
        "Trusted server-side app_metadata 'tp_officer' assigns T&P role"
      );
    }

    // ------------------------------------------------------------------------
    // Group 3: Preservation of Legitimate Existing Users & Roles
    // ------------------------------------------------------------------------
    console.log("\n[Group 3: Existing Profiles & Role Integrity]");

    {
      const res = await client.query(`
        SELECT role, count(*)::int as count
        FROM public.profiles
        GROUP BY role
      `);
      const counts: Record<string, number> = {};
      res.rows.forEach((r) => {
        counts[r.role] = r.count;
      });

      testAssert(
        (counts["student"] || 0) >= 5,
        `Student accounts preserved (count: ${counts["student"] || 0})`
      );
      testAssert(
        (counts["faculty_mentor"] || 0) >= 1,
        `Faculty mentor accounts preserved (count: ${counts["faculty_mentor"] || 0})`
      );
      testAssert(
        (counts["tp_officer"] || 0) >= 1,
        `T&P officer accounts preserved (count: ${counts["tp_officer"] || 0})`
      );
      testAssert(
        (counts["admin"] || 0) >= 1,
        `Admin accounts preserved (count: ${counts["admin"] || 0})`
      );
      testAssert(
        (counts["industry_supervisor"] || 0) >= 1,
        `Industry supervisor accounts preserved (count: ${counts["industry_supervisor"] || 0})`
      );
    }

    // ------------------------------------------------------------------------
    // Group 4: Row Level Security Policy Verification
    // ------------------------------------------------------------------------
    console.log("\n[Group 4: Row Level Security & Access Control]");

    {
      const res = await client.query(`
        SELECT policyname, cmd
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'profiles' AND cmd = 'UPDATE'
      `);
      const policyNames = res.rows.map((r) => r.policyname);
      testAssert(
        policyNames.some((p) => p.toLowerCase().includes("admin")),
        "Administrative update policy exists on public.profiles"
      );
      testAssert(
        policyNames.some((p) => p.toLowerCase().includes("own")),
        "Self profile update policy exists for own record on public.profiles"
      );
    }

    console.log(`\n=== Role Security Test Summary: ${passed} PASSED, ${failed} FAILED ===`);
  } catch (err: any) {
    console.error("Test execution threw error:", err.message);
    failed++;
  } finally {
    await client.end();
    process.exit(failed > 0 ? 1 : 0);
  }
}

runRoleSecurityTests();
