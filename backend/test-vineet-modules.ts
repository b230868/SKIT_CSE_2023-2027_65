/**
 * Automated Verification Script for Vineet Meena's User Stories
 * Using Node's native http server & fetch
 */

import http from "http";
import app from "./src/app";

async function runVerification() {
  console.log("=================================================");
  console.log("STARTING BACKEND VERIFICATION FOR VINEET'S SCOPE");
  console.log("=================================================");

  const server = http.createServer(app);
  await new Promise<void>((resolve) => server.listen(0, resolve));
  const address = server.address() as any;
  const port = address.port;
  const baseUrl = `http://localhost:${port}`;

  let passed = 0;
  let total = 0;

  function assert(condition: boolean, testName: string) {
    total++;
    if (condition) {
      console.log(`  [PASS] ${testName}`);
      passed++;
    } else {
      console.error(`  [FAIL] ${testName}`);
      process.exitCode = 1;
    }
  }

  try {
    // 1. Health check (public)
    const healthRes = await fetch(`${baseUrl}/health`);
    const healthJson: any = await healthRes.json();
    assert(healthRes.status === 200, "GET /health returns HTTP 200");
    assert(healthJson.data?.status === "ok", "GET /health reports status 'ok'");

    // 2. Monitoring route security (requires auth)
    const monRes = await fetch(`${baseUrl}/monitoring/students`);
    assert(monRes.status === 401, "GET /monitoring/students rejects unauthenticated request with 401");

    // 3. Approvals route security (requires auth)
    const appRes = await fetch(`${baseUrl}/approvals`);
    assert(appRes.status === 401, "GET /approvals rejects unauthenticated request with 401");

    // 4. Reports route security (requires auth)
    const repRes = await fetch(`${baseUrl}/reports/faculty`);
    assert(repRes.status === 401, "GET /reports/faculty rejects unauthenticated request with 401");

    // 5. ERP route security (requires auth)
    const erpRes = await fetch(`${baseUrl}/erp/status`);
    assert(erpRes.status === 401, "GET /erp/status rejects unauthenticated request with 401");

    // 6. 404 handler for nonexistent route
    const notFoundRes = await fetch(`${baseUrl}/non-existent-endpoint-test`);
    assert(notFoundRes.status === 404, "Unknown route returns HTTP 404");

    console.log("-------------------------------------------------");
    console.log(`Verification Summary: ${passed}/${total} tests passed!`);
    console.log("=================================================");
  } finally {
    server.close();
  }
}

runVerification().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
