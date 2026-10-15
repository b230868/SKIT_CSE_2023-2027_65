# Prashikshan Backend — Express + Prisma + Supabase

This directory contains the Node.js backend for the **Prashikshan** internship and training management system. It provides a RESTful API layer built with **Express.js**, **TypeScript**, and **Prisma ORM 7**, connecting directly to the Supabase PostgreSQL database while reusing Supabase Auth for unified identity management.

---

## 1. System Architecture

Prashikshan utilizes a **hybrid architecture** that balances client-side productivity with server-side security and performance:

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Client                       │
│  (UI Screens, State Management, Local Hive Cache)      │
└──────────────┬──────────────────────────┬──────────────┘
               │                          │
        1. Auth & Storage          2. REST API Requests
     (Supabase Client SDK)      (Bearer JWT in Authorization)
               │                          │
               ▼                          ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│   Supabase Cloud / Auth  │    │   Prashikshan Express    │
│  - Email/Password Auth   │    │   - Request Logger       │
│  - JWT Token Issuance    │◄───┤   - Token Verification   │
│  - Document Storage      │    │   - Role-Based Auth (RBAC)│
└──────────────────────────┘    │   - Input Validation     │
                                └─────────────┬────────────┘
                                              │
                                       3. Prisma ORM 7
                                    (@prisma/adapter-pg)
                                              │
                                              ▼
                                ┌──────────────────────────┐
                                │   Supabase PostgreSQL    │
                                │   - 48 introspected tables│
                                │   - Foreign key relations│
                                └──────────────────────────┘
```

### Why a Hybrid Architecture?
- **Supabase Direct (Client)**: Authentication sessions, token lifecycle, and file/document uploads (avatars, ITR documents, certificates) are seamlessly handled by `supabase_flutter`.
- **Node.js/Prisma Backend (Server)**: Complex data aggregation, cross-table queries, student monitoring, validation, and administrative operations are processed securely with typed Prisma ORM queries.
- **Security Isolation**: Database credentials and connection strings reside exclusively on the server, never compiled into mobile binaries.

---

## 2. Technology Stack

- **Runtime**: Node.js v24+
- **Language**: TypeScript with ES2022 and NodeNext module resolution
- **Web Framework**: Express v5
- **ORM**: Prisma v7 (`@prisma/client`, `@prisma/adapter-pg`, `pg`)
- **Authentication**: Supabase Auth verification via `@supabase/supabase-js`
- **Validation**: Zod schema validation
- **Execution & Testing**: `tsx` (TypeScript Execute), native `fetch` integration tests

---

## 3. Directory Structure

```
backend/
├── prisma/
│   └── schema.prisma        # Introspected database schema (48 models)
├── generated/
│   └── prisma/              # Prisma Client output directory
├── src/
│   ├── config/
│   │   ├── db.ts            # Single managed PrismaClient instance & graceful shutdown
│   │   └── supabase.ts      # Supabase Auth client for JWT verification
│   ├── controllers/
│   │   ├── student.controller.ts    # Student profiles, listings, updates
│   │   ├── internship.controller.ts # Internships & progress updates
│   │   └── monitoring.controller.ts # Aggregated student monitoring items
│   ├── middleware/
│   │   ├── auth.ts          # Supabase JWT authentication & requireRole RBAC
│   │   ├── errorHandler.ts  # Centralized error handler & safe sanitization
│   │   └── logger.ts        # Request logging with sensitive field redaction
│   ├── routes/
│   │   ├── student.routes.ts        # /students endpoints
│   │   ├── internship.routes.ts     # /internships endpoints
│   │   └── monitoring.routes.ts     # /monitoring endpoints
│   ├── utils/
│   │   ├── response.ts      # Standard ApiResponse and ApiError classes
│   │   └── validators.ts    # UUID regex helper and Zod schemas
│   └── app.ts               # Express application configuration
├── test/
│   └── api.test.ts          # Comprehensive 40-test integration suite
├── .env.example             # Template for required environment variables
├── package.json             # NPM dependencies and development scripts
├── prisma7.config.ts        # Prisma 7 configuration file
├── server.ts                # Application entrypoint with graceful shutdown
└── tsconfig.json            # TypeScript compiler configuration
```

---

## 4. Environment Setup

Copy `.env.example` to create your local `.env` file:

```bash
cp .env.example .env
```

Configure the following variables in `backend/.env`:

| Variable | Description | Example |
| :--- | :--- | :--- |
| `DATABASE_URL` | PostgreSQL connection string with SSL | `postgresql://postgres.[ref]:[pass]@[host]:5432/postgres` |
| `SUPABASE_URL` | Your Supabase project URL | `https://[ref].supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | Client publishable/anon key for auth | `eyJhbGci...` |
| `PORT` | Express server port (defaults to 3000) | `3000` |

> **Security Note**: Never commit `.env` to Git. Both root and backend `.gitignore` exclude `.env` by default.

---

## 5. Development & Execution Commands

Run these commands inside the `backend` directory:

```bash
# 1. Install dependencies
npm install

# 2. Generate Prisma Client
npm run prisma:generate

# 3. Verify TypeScript type checking
npm run typecheck

# 4. Run the automated integration test suite
npm test

# 5. Start the development server (with auto-reload)
npm run dev

# 6. Start the production server
npm start
```

---

## 6. API Reference

All successful responses follow the consistent envelope:
```json
{
  "success": true,
  "message": "Optional descriptive message",
  "data": { ... },
  "count": 10,
  "pagination": { "page": 1, "limit": 20, "total": 50, "totalPages": 3 }
}
```

All error responses return:
```json
{
  "success": false,
  "message": "Error description",
  "errors": [ ... ]
}
```

### Health & Diagnostics

#### `GET /`
- **Purpose**: Health check / status verification.
- **Auth**: Public.
- **Response `200`**:
  ```json
  {
    "message": "Prashikshan backend is running!",
    "version": "1.0.0",
    "status": "healthy"
  }
  ```

#### `GET /db-test`
- **Purpose**: Verifies direct connection between Prisma and Supabase PostgreSQL.
- **Auth**: Required (`Bearer <token>`). Restricted to staff (`faculty_mentor`, `tp_officer`, `admin`).
- **Response `200`**:
  ```json
  {
    "success": true,
    "message": "Supabase connection successful!",
    "database": "postgres"
  }
  ```

#### `GET /health`
- **Purpose**: Safe public liveness and uptime diagnostics (no database internals or latencies leaked).
- **Auth**: Public.

---

### Student APIs (`/students`)

#### `GET /students`
- **Purpose**: Retrieve paginated list of students with safe profile fields.
- **Auth**: Required (`Bearer <token>`). Restricted to staff (`faculty_mentor`, `tp_officer`, `admin`).
- **Query Parameters**:
  - `page` (number, default: 1)
  - `limit` (number, default: 20)
  - `department` (string, case-insensitive filter)
  - `batch_year` (number)
  - `search` (string, matches roll number or name)
- **Response `200`**:
  ```json
  {
    "success": true,
    "count": 1,
    "pagination": { "page": 1, "limit": 20, "total": 1, "totalPages": 1 },
    "data": [
      {
        "id": "e7240007-23be-4b91-9d38-45cd555ed251",
        "user_id": "d2763055-f48e-43aa-9c3f-d8a592965d74",
        "roll_number": "23eskcs113",
        "department": "computer science",
        "batch_year": 2026,
        "full_name": "Student Name",
        "email": "student@example.com",
        "avatar_url": "https://...",
        "branch": "computer science",
        "enrollment_no": "23eskcs113",
        "created_at": "2026-09-03T10:09:11.656Z"
      }
    ]
  }
  ```

#### `GET /students/me`
- **Purpose**: Retrieves the profile, student record, and internships for the currently authenticated student.
- **Auth**: Required (`Bearer <token>`).

#### `GET /students/:id`
- **Purpose**: Retrieve a single student by UUID.
- **Auth**: Required (`Bearer <token>`). Enforces ownership (students can only access their own record; staff can access any).
- **Response `200`**: Full student object including profile details and active internships.
- **Response `400`**: If `:id` is not a valid UUID format.
- **Response `404`**: If student is not found.

#### `PATCH /students/:id`
- **Purpose**: Update student profile fields (`department`, `batch_year`, `full_name`, `phone_number`, `address`, `branch`).
- **Auth**: Required. Enforces that students can only update their own record, while faculty/admin can update any.

---

### Internship APIs (`/internships`)

#### `GET /internships`
- **Purpose**: List internships with filtering (`status`, `student_id`, `department`).
- **Auth**: Required (`Bearer <token>`).
- **Role Scoping**:
  - `student`: Automatically scoped to return only their own internships.
  - `faculty_mentor` / `tp_officer` / `admin`: Full visibility across students.

#### `GET /internships/:id`
- **Purpose**: Retrieve complete internship details, industry metadata, progress updates, and reviews.
- **Auth**: Required. Validates UUID and ownership.

#### `POST /internships`
- **Purpose**: Create a new internship application.
- **Auth**: Required. If authenticated as a student, `student_id` is automatically set to the user's student ID.

#### `PATCH /internships/:id`
- **Purpose**: Update internship details or progress.
- **Auth**: Required. Students cannot unilaterally change status (requires staff review).

#### `GET /internships/:id/progress`
- **Purpose**: List progress updates for an internship in reverse chronological order.
- **Auth**: Required.

#### `POST /internships/:id/progress`
- **Purpose**: Log a new progress milestone. Automatically updates `internships.progress`.
- **Request Body**:
  ```json
  {
    "progress_percentage": 75,
    "update_text": "Completed database migration and unit tests."
  }
  ```

---

### Student Monitoring APIs (`/monitoring`)

#### `GET /monitoring/students`
- **Purpose**: High-performance aggregated student monitoring endpoint specifically matching Flutter's `StudentMonitoringItem` contract.
- **Auth**: Required (`Bearer <token>`).
- **Allowed Roles**: `faculty_mentor`, `tp_officer`, `admin`.
- **Response `200`**:
  ```json
  {
    "success": true,
    "count": 2,
    "data": [
      {
        "studentId": "e7240007-23be-4b91-9d38-45cd555ed251",
        "studentName": "Rahul Sharma",
        "internshipId": "2e368c23-d6e3-48a4-9359-7366745900b8",
        "internshipTitle": "Flutter Intern",
        "applicationStatus": "active",
        "department": "computer science",
        "rollNumber": "23eskcs113"
      }
    ]
  }
  ```

---

## 7. Authentication, Authorization & Security Architecture

### Supabase JWT Verification
1. The Flutter client acquires a session from Supabase Auth (`supabase.auth.signInWithPassword`).
2. When calling protected backend routes, Flutter includes the access token:
   `Authorization: Bearer <session.accessToken>`
3. Backend middleware (`src/middleware/auth.ts`) extracts the token and validates it against Supabase Auth servers using `supabase.auth.getUser(token)`.
4. If the token is expired, missing, or altered, a `401 Unauthorized` response is returned.

### Role-Based Access Control (RBAC)
Because Prisma connects directly to PostgreSQL via connection string, it bypasses PostgreSQL Row Level Security (RLS). Therefore, **all authorization rules are enforced strictly at the Express application layer**:
- `profiles.role` is queried directly from PostgreSQL using the verified Supabase user ID.
- Allowed roles strictly reflect the database `app_role` enum:
  - `student`
  - `faculty_mentor`
  - `tp_officer`
  - `industry_supervisor`
  - `admin`
- User ownership is checked on all write and profile retrieval endpoints: user IDs in request bodies or URLs are never blindly trusted.

---

## 8. Flutter Integration Architecture

Flutter interacts with the backend using the following decoupled components:

1. **`lib/core/config/backend_config.dart`**:
   Automatically detects the platform runtime:
   - Android Emulator: `http://10.0.2.2:3000`
   - iOS Simulator / Desktop / Web: `http://localhost:3000`
   - Configurable via `BACKEND_URL` in `.env` or programmatic overrides.

2. **`lib/core/network/api_client.dart`**:
   - Automatically injects the active Supabase session access token (`Authorization: Bearer <token>`).
   - Handles network timeouts (15 seconds default) and socket exceptions gracefully.
   - Throws typed `ApiException` instances with status codes and parsed error messages.

3. **`BackendStudentMonitoringRepository`**:
   Implements `StudentMonitoringRepository` by calling `GET /monitoring/students`, enabling the Flutter UI to use the Express backend seamlessly while maintaining fallback to Supabase and Mock repositories via `StudentMonitoringRepositoryFactory`.

---

## 9. Troubleshooting & FAQ

### 1. `Can't reach database server at ...` (Prisma error P1001)
- Verify that `DATABASE_URL` in `backend/.env` is on a single line and ends with `?sslmode=require` or is quoted properly.
- Ensure your internet connection allows outbound traffic on PostgreSQL port `5432` or pooled port `6543`.

### 2. `HTTP 401 Unauthorized: Authentication token required`
- Verify that the Flutter user is logged in via Supabase before calling protected endpoints.
- Check that the header format is exactly `Authorization: Bearer <token>`.

### 3. Android Emulator cannot connect to `http://localhost:3000`
- `localhost` inside the Android emulator refers to the emulator itself. Use `http://10.0.2.2:3000` (which `BackendConfig` sets automatically for Android).

### 4. `Request validation failed` (HTTP 400)
- The request body failed Zod validation. Check the `errors` array in the response for field-level validation messages.

---

## 10. Supabase Email Delivery & Rate Limit Architecture

### The Four Rate-Limit Layers Explained
To maintain system stability, security, and spam prevention, authentication email requests pass through four distinct layers:

1. **Supabase Built-in Mailer Quota (2 to 4 emails/hour)**:
   - *Scope*: Project-wide limit enforced on Supabase free tier when using the default built-in mailer.
   - *Impact*: Triggers HTTP 429 `{"code": 429, "msg": "over_email_send_rate_limit"}`.
   - *Mitigation*: Completely bypassed when either **Custom SMTP** or the **Send Email Hook** is enabled in the Supabase Cloud Console.

2. **Supabase Auth Per-User & IP Endpoint Limits (Non-bypassable anti-abuse)**:
   - *Scope*: Enforced by Supabase GoTrue Auth regardless of whether custom SMTP or hooks are used.
   - *Behavior*: A 60-second cooldown per individual recipient email for OTP/magiclink/recovery requests, plus IP-based burst protection (default 30 requests/hour per IP).
   - *Mitigation*: Legitimate security policy; handled gracefully in Flutter UI via `AuthService.parseAuthErrorMessage()`.

3. **External Email Provider Quotas (Provider-specific)**:
   - *Scope*: Governed by your third-party transactional mailer (e.g. Resend, Brevo, AWS SES).
   - *Limits*: e.g., Resend Free tier allows up to 3,000 emails/month (max 100 emails/day).
   - *Note*: Neither Custom SMTP nor hooks provide "unlimited" emails; delivery volume is governed by the chosen provider's tier.

4. **Application In-Flight Concurrency Protection**:
   - *Scope*: Flutter client layer (`_isEmailActionInProgress` in `AuthService`).
   - *Behavior*: Prevents accidental double-clicks during active network transit. Controls re-enable immediately in `finally` blocks upon completion or server error with **zero artificial waiting timers**.

---

### Failure Propagation & No False Success
The Send Email Hook implementation strictly adheres to the official Supabase Hook contract:
- **No False Success**: If no provider API key (`RESEND_API_KEY`) is configured, or if provider delivery fails, the hook returns an explicit error response (`HTTP 503` or `HTTP 422`) with `{ "error": { "http_code": 503, "message": "..." } }`. It NEVER returns `HTTP 200 {}` unless the email has actually been dispatched.
- **No Sensitive Logging**: Tokens, hashes, and OTP secrets are never logged in any environment, masked or unmasked.

---

### Choosing Between Custom SMTP vs Send Email Hook

| Consideration | Custom SMTP (Primary Recommendation) | Send Email Hook (Advanced) |
| :--- | :--- | :--- |
| **Setup Complexity** | Zero code; configured in Supabase Dashboard in 2 minutes | Requires deployed backend endpoint or Edge Function |
| **Hosting Overhead** | None (managed by Supabase Auth GoTrue directly) | Requires running server or Deno Edge Function |
| **Template Customization** | Uses Supabase Dashboard email templates | Full custom HTML/React-Email generation in code |
| **Webhook Auditing** | None | Full request logging and telemetry |

#### Option 1: Custom SMTP (Direct Dashboard Setup)
1. In the Supabase Dashboard, go to **Project Settings** -> **Authentication** -> **SMTP Settings**.
2. Toggle **Enable Custom SMTP**.
3. Configure your provider credentials (e.g. Resend, Brevo, SES):
   - **Sender Email**: `noreply@yourdomain.edu` (or `onboarding@resend.dev` for Resend tests)
   - **Host**: `smtp.resend.com` | **Port**: `465` (SSL) or `587` (TLS)
   - **User**: `resend` | **Password**: `<Your_Resend_API_Key>`
4. Save changes.

#### Option 2: Send Email Hook (Endpoint / Edge Function)
1. Deploy either:
   - The Express endpoint: `POST https://<your-domain>/auth/send-email-hook`
   - The Deno Edge Function: `supabase functions deploy send-email --no-verify-jwt`
2. In Supabase Dashboard -> **Authentication** -> **Hooks** -> **Send Email Hook**:
   - Toggle **Enable Send Email Hook**.
   - Set URL and Hook Secret (`SEND_EMAIL_HOOK_SECRET`).
3. Set `RESEND_API_KEY` in `backend/.env` or via `supabase secrets set RESEND_API_KEY=...`.
