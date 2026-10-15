import "dotenv/config";
import http from "http";
import app from "../src/app";
import { disconnectPrisma } from "../src/config/db";
import { supabase } from "../src/config/supabase";

let server: http.Server;
let baseUrl: string;
let facultyToken: string = "";
let sampleStudentId: string = "";
let sampleInternshipId: string = "";

// Helper to make HTTP requests
async function request(
  method: string,
  path: string,
  options?: {
    body?: any;
    token?: string;
  }
): Promise<{ status: number; body: any }> {
  const url = `${baseUrl}${path}`;
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
  };

  if (options?.token) {
    headers["Authorization"] = `Bearer ${options.token}`;
  }

  const res = await fetch(url, {
    method,
    headers,
    body: options?.body ? JSON.stringify(options.body) : undefined,
  });

  const body = await res.json().catch(() => null);
  return { status: res.status, body };
}

async function runTests() {
  console.log("=== Prashikshan Backend Automated Integration Test Suite ===");
  let passed = 0;
  let failed = 0;

  function assert(condition: boolean, testName: string, errorDetail?: any) {
    if (condition) {
      console.log(`  ✓ PASS: ${testName}`);
      passed++;
    } else {
      console.error(`  ✗ FAIL: ${testName}`, errorDetail || "");
      failed++;
    }
  }

  try {
    // 1. Start server on an ephemeral port
    await new Promise<void>((resolve) => {
      server = app.listen(0, () => {
        const addr = server.address() as any;
        baseUrl = `http://localhost:${addr.port}`;
        console.log(`Test server running at ${baseUrl}`);
        resolve();
      });
    });

    // 2. Fetch a valid Supabase Auth token for Faculty test account
    console.log("\n[Setup] Authenticating faculty test account...");
    const { data: authData, error: authErr } =
      await supabase.auth.signInWithPassword({
        email: "faculty@faculty.com",
        password: "Faculty@123",
      });

    if (authErr || !authData.session?.access_token) {
      console.warn("Could not authenticate test faculty:", authErr?.message);
    } else {
      facultyToken = authData.session.access_token;
      console.log("Faculty token acquired successfully.");
    }

    // --- TEST 1: Server health & status ---
    console.log("\n[Group 1: Health & Diagnostics]");
    {
      const res = await request("GET", "/");
      assert(res.status === 200, "GET / returns HTTP 200");
      assert(
        res.body?.message === "Prashikshan backend is running!",
        "GET / returns expected running message"
      );
    }

    {
      const res = await request("GET", "/health");
      assert(res.status === 200, "GET /health returns HTTP 200");
      assert(
        res.body?.data?.status === "ok",
        "GET /health reports status: ok"
      );
    }

    {
      // /db-test is protected: must reject unauthenticated requests
      const res = await request("GET", "/db-test");
      assert(
        res.status === 401,
        "GET /db-test without token returns HTTP 401 Unauthorized"
      );
    }

    if (facultyToken) {
      const res = await request("GET", "/db-test", { token: facultyToken });
      assert(
        res.status === 200,
        "GET /db-test with authorized faculty token returns HTTP 200"
      );
      assert(res.body?.success === true, "GET /db-test success is true");
      assert(
        typeof res.body?.database === "string",
        `GET /db-test reports database name: ${res.body?.database}`
      );
    }

    // --- TEST 2: Student APIs ---
    console.log("\n[Group 2: Student APIs]");
    {
      // Unauthenticated access must be blocked
      const res = await request("GET", "/students");
      assert(
        res.status === 401,
        "GET /students without token returns HTTP 401 Unauthorized"
      );
    }

    if (facultyToken) {
      {
        const res = await request("GET", "/students", { token: facultyToken });
        assert(res.status === 200, "GET /students with faculty token returns HTTP 200");
        assert(res.body?.success === true, "GET /students response success is true");
        assert(Array.isArray(res.body?.data), "GET /students returns array of students");
        assert(
          typeof res.body?.count === "number" && res.body.count >= 1,
          `GET /students returns student records (count: ${res.body?.count})`
        );

        if (res.body?.data?.length > 0) {
          sampleStudentId = res.body.data[0].id;
          const first = res.body.data[0];
          assert(
            typeof first.roll_number === "string" && first.roll_number.length > 0,
            "Student contains roll_number"
          );
          assert(
            typeof first.department === "string" && first.department.length > 0,
            "Student contains department"
          );
        }
      }

      {
        const res = await request("GET", "/students?limit=2&page=1", {
          token: facultyToken,
        });
        assert(res.status === 200, "GET /students with pagination returns HTTP 200");
        assert(
          res.body?.pagination?.limit === 2 && res.body?.pagination?.page === 1,
          "GET /students pagination metadata matches request"
        );
      }

      {
        // Unauthenticated access to /students/:id must be blocked
        const res = await request("GET", `/students/${sampleStudentId}`);
        assert(
          res.status === 401,
          "GET /students/:id without token returns HTTP 401 Unauthorized"
        );
      }

      {
        assert(
          !!sampleStudentId,
          `Sample student ID acquired for detail test: ${sampleStudentId}`
        );
        const res = await request("GET", `/students/${sampleStudentId}`, {
          token: facultyToken,
        });
        assert(res.status === 200, "GET /students/:id with valid UUID returns HTTP 200");
        assert(
          res.body?.data?.id === sampleStudentId,
          "GET /students/:id returns the requested student"
        );
        assert(
          res.body?.data?.profiles !== undefined,
          "GET /students/:id includes associated profile"
        );
      }

      {
        const fakeUuid = "00000000-0000-0000-0000-000000000000";
        const res = await request("GET", `/students/${fakeUuid}`, {
          token: facultyToken,
        });
        assert(res.status === 404, "GET /students/:id with non-existent UUID returns HTTP 404");
        assert(res.body?.success === false, "404 response success is false");
      }

      {
        const res = await request("GET", "/students/not-a-valid-uuid", {
          token: facultyToken,
        });
        assert(res.status === 400, "GET /students/:id with invalid UUID format returns HTTP 400");
        assert(
          res.body?.message?.includes("valid UUID"),
          "400 error specifies invalid UUID format"
        );
      }
    }

    // --- TEST 3: Authentication & Security ---
    console.log("\n[Group 3: Authentication, Authorization & Security]");
    {
      // Attempting to access protected monitoring endpoint without token
      const res = await request("GET", "/monitoring/students");
      assert(
        res.status === 401,
        "GET /monitoring/students without token returns HTTP 401 Unauthorized"
      );
      assert(
        res.body?.success === false,
        "Unauthenticated response success is false"
      );
    }

    {
      // Attempting to access with forged/invalid token
      const res = await request("GET", "/monitoring/students", {
        token: "forged.jwt.token.here",
      });
      assert(
        res.status === 401,
        "GET /monitoring/students with invalid token returns HTTP 401"
      );
    }

    {
      // Attempting to access with valid Faculty token
      if (facultyToken) {
        const res = await request("GET", "/monitoring/students", {
          token: facultyToken,
        });
        assert(
          res.status === 200,
          "GET /monitoring/students with valid Faculty token returns HTTP 200"
        );
        assert(
          Array.isArray(res.body?.data),
          "Monitoring data is an array"
        );
        if (res.body?.data?.length > 0) {
          const item = res.body.data[0];
          assert(
            typeof item.studentName === "string" &&
              typeof item.internshipTitle === "string" &&
              typeof item.applicationStatus === "string",
            "Monitoring item matches Flutter StudentMonitoringItem schema"
          );
          sampleInternshipId = item.internshipId;
        }
      }
    }

    // --- TEST 4: Internship APIs ---
    console.log("\n[Group 4: Internship APIs]");
    {
      const res = await request("GET", "/internships");
      assert(
        res.status === 401,
        "GET /internships without token returns HTTP 401"
      );
    }

    if (facultyToken) {
      {
        const res = await request("GET", "/internships", {
          token: facultyToken,
        });
        assert(
          res.status === 200,
          "GET /internships with Faculty token returns HTTP 200"
        );
        assert(Array.isArray(res.body?.data), "Internships data is an array");
        if (res.body?.data?.length > 0 && !sampleInternshipId) {
          sampleInternshipId = res.body.data[0].id;
        }
      }

      if (sampleInternshipId) {
        {
          const res = await request("GET", `/internships/${sampleInternshipId}`, {
            token: facultyToken,
          });
          assert(
            res.status === 200,
            "GET /internships/:id with valid ID returns HTTP 200"
          );
          assert(
            res.body?.data?.id === sampleInternshipId,
            "GET /internships/:id returns correct record"
          );
        }

        {
          const res = await request(
            "GET",
            `/internships/${sampleInternshipId}/progress`,
            { token: facultyToken }
          );
          assert(
            res.status === 200,
            "GET /internships/:id/progress returns HTTP 200"
          );
          assert(Array.isArray(res.body?.data), "Progress updates is an array");
        }
      }

      {
        const fakeId = "00000000-0000-0000-0000-000000000000";
        const res = await request("GET", `/internships/${fakeId}`, {
          token: facultyToken,
        });
        assert(
          res.status === 404,
          "GET /internships/:id with non-existent ID returns HTTP 404"
        );
      }

      {
        const res = await request("GET", "/internships/bad-id", {
          token: facultyToken,
        });
        assert(
          res.status === 400,
          "GET /internships/:id with malformed UUID returns HTTP 400"
        );
      }
    }

    // --- TEST 5: 404 Not Found & Malformed requests ---
    console.log("\n[Group 5: Error Handling & Routing]");
    {
      const res = await request("GET", "/api/non-existent-route");
      assert(res.status === 404, "Unknown route returns HTTP 404");
      assert(
        res.body?.success === false,
        "Unknown route returns formatted JSON error"
      );
    }

    // --- TEST 6: Supabase Auth Send Email Hook & Delivery Architecture ---
    console.log("\n[Group 6: Supabase Auth Send Email Hook & Delivery Architecture]");
    {
      const res = await request("GET", "/auth/email-hook-status");
      assert(res.status === 200, "GET /auth/email-hook-status returns HTTP 200");
      assert(
        res.body?.success === true,
        "GET /auth/email-hook-status response success is true"
      );
      assert(
        Array.isArray(res.body?.data?.supportedActions),
        "Email hook supports expected auth action types"
      );
      assert(
        res.body?.data?.rateLimitLayers?.builtInSupabaseQuota !== undefined,
        "Email hook status includes Supabase quota mitigation details"
      );
      assert(
        res.body?.data?.deliveryStatus !== undefined,
        "Email hook status reports delivery readiness"
      );
    }

    {
      const res = await request("POST", "/auth/send-email-hook", {
        body: {},
      });
      assert(
        res.status === 400,
        "POST /auth/send-email-hook with empty body returns HTTP 400"
      );
      assert(
        res.body?.error !== undefined,
        "Empty payload returns Supabase error envelope"
      );
    }

    {
      const res = await request("POST", "/auth/send-email-hook", {
        body: {
          user: { id: "test-user-id", email: "" },
          email_data: { token: "123456", email_action_type: "signup" },
        },
      });
      assert(
        res.status === 400,
        "POST /auth/send-email-hook without recipient email returns HTTP 400"
      );
    }

    {
      // Failure Propagation Test: Unconfigured provider MUST return HTTP 503 (No False Success)
      delete process.env.ALLOW_TEST_SIMULATED_DISPATCH;
      delete process.env.RESEND_API_KEY;

      const res = await request("POST", "/auth/send-email-hook", {
        body: {
          user: {
            id: "test-user-unconfigured",
            email: "student.test@college.edu",
          },
          email_data: {
            token: "582910",
            token_hash: "mock_hash_for_unconfigured_test",
            redirect_to: "http://localhost:3000/",
            email_action_type: "signup",
            site_url: "http://localhost:3000",
          },
        },
      });
      assert(
        res.status === 503,
        "Unconfigured provider rejects with HTTP 503 and prevents false success"
      );
      assert(
        res.body?.error?.http_code === 503,
        "Error response contains standard Supabase error object with http_code 503"
      );
    }

    {
      // Webhook Secret Authorization Test
      process.env.SEND_EMAIL_HOOK_SECRET = "v1,whsec_mock_test_secret_value_123";

      // Missing authorization returns 401
      const unauthRes = await request("POST", "/auth/send-email-hook", {
        body: {
          user: { id: "test-user-id", email: "student.test@college.edu" },
          email_data: { token: "123456", email_action_type: "signup" },
        },
      });
      assert(
        unauthRes.status === 401,
        "Configured secret rejects requests without signature/Bearer token with HTTP 401"
      );

      delete process.env.SEND_EMAIL_HOOK_SECRET;
    }

    {
      // Test Dispatcher: with test simulation flag enabled, returns HTTP 200 {} without logging secrets
      process.env.ALLOW_TEST_SIMULATED_DISPATCH = "true";

      const res = await request("POST", "/auth/send-email-hook", {
        body: {
          user: {
            id: "test-user-1234",
            email: "student.test@college.edu",
            user_metadata: { full_name: "Test Student" },
          },
          email_data: {
            token: "582910",
            token_hash: "mock_hash_for_signup_test",
            redirect_to: "http://localhost:3000/",
            email_action_type: "signup",
            site_url: "http://localhost:3000",
          },
        },
      });
      assert(
        res.status === 200,
        "POST /auth/send-email-hook with valid signup payload returns HTTP 200"
      );
      assert(
        typeof res.body === "object" && Object.keys(res.body).length === 0,
        "Send Email Hook responds with empty JSON object {} per Supabase protocol"
      );
    }

    {
      const res = await request("POST", "/auth/send-email-hook", {
        body: {
          user: {
            id: "test-user-5678",
            email: "faculty.test@college.edu",
            user_metadata: { full_name: "Dr. Faculty" },
          },
          email_data: {
            token: "991823",
            token_hash: "mock_hash_for_recovery_test",
            redirect_to: "http://localhost:3000/reset",
            email_action_type: "recovery",
            site_url: "http://localhost:3000",
          },
        },
      });
      assert(
        res.status === 200,
        "POST /auth/send-email-hook with valid password recovery payload returns HTTP 200"
      );

      delete process.env.ALLOW_TEST_SIMULATED_DISPATCH;
    }

    console.log(`\n=== Integration Test Summary: ${passed} PASSED, ${failed} FAILED ===`);
  } catch (err) {
    console.error("Test execution threw exception:", err);
  } finally {
    if (server) {
      server.close();
    }
    await disconnectPrisma();
    process.exit(failed > 0 ? 1 : 0);
  }
}

runTests();
