# Prashikshan Production Deployment Guide

This document details the complete deployment setup, database configuration, container orchestration, and ERP integration procedures for the **Prashikshan** internship and training management system.

---

## 1. System Deployment Architecture

```
                    +-----------------------------+
                    |        Client Layer         |
                    | Flutter Mobile / Web Client |
                    +--------------+--------------+
                                   |
                +------------------+------------------+
                |                                     |
                v                                     v
   +------------------------+             +------------------------+
   |   Supabase Services    |             |  Backend API Server    |
   | - GoTrue Authentication|             | - Express.js REST API  |
   | - S3 Document Storage  |             | - Role-Based Auth RBAC |
   | - Realtime Events      |             | - Prisma ORM 7 Engine  |
   +-----------+------------+             +-----------+------------+
               |                                      |
               +------------------+-------------------+
                                  |
                                  v
                    +-----------------------------+
                    |     Supabase PostgreSQL     |
                    | - Connection Pooler (6543)  |
                    | - Direct Migrations (5432)  |
                    | - 48 Introspected Tables    |
                    +--------------+--------------+
                                   |
                                   v
                    +-----------------------------+
                    |     College ERP System      |
                    | - Academic Credit Sync      |
                    | - Verified Placement Records|
                    +-----------------------------+
```

---

## 2. Prerequisites

- **Docker & Docker Compose**: v24.0+
- **Node.js**: v22+ (for local builds and migration tasks)
- **Supabase Cloud Project**: Active PostgreSQL instance with database pooling enabled.
- **SSL Certificate**: Valid domain certificate (e.g. Let's Encrypt / Certbot) for production HTTPS.

---

## 3. Database Preparation & Migration

### Step 3.1: Environment Setup
Copy the production environment template:
```bash
cp backend/.env.production.example backend/.env.production
```
Configure your credentials in `backend/.env.production`:
- Set `DATABASE_URL` with transaction pooling mode on port `6543`.
- Set `DIRECT_URL` with session mode on port `5432`.
- Configure `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.

### Step 3.2: Database Migration & Schema Sync
Generate Prisma client and apply schema:
```bash
cd backend
npx prisma generate
```

Apply database optimization indexes:
```bash
# Execute optimization indexes from supabase/migrations/20270216_database_optimization.sql
```

---

## 4. Docker Deployment Setup

### Step 4.1: Building the Production Image
Build the backend image using Docker:
```bash
docker compose build backend
```

### Step 4.2: Running the Services
Launch containerized services in detached mode:
```bash
docker compose up -d
```

### Step 4.3: Health Check Verification
Verify container health:
```bash
docker compose ps
curl -i http://localhost:3000/health
```

Expected response:
```json
{
  "success": true,
  "data": {
    "status": "ok",
    "uptime": 12.4,
    "timestamp": "2027-02-01T10:00:00.000Z"
  }
}
```

---

## 5. College ERP Deployment Integration

The Prashikshan backend exposes dedicated ERP endpoints:
1. **ERP Connectivity Status**: `GET /erp/status`
   - Checks latency and database sync readiness.
2. **ERP Export**: `GET /erp/export`
   - Formatted academic records ready for ERP ingestion.
3. **ERP Database Configuration**: `POST /erp/configure-db`
   - Update target ERP host, port, database, and sync intervals.
4. **ERP Push Sync**: `POST /erp/sync-records`
   - Automatically synchronizes approved internships and grades into College ERP.

---

## 6. Security & Monitoring Checklist

- [x] Zero plain text secrets in client binaries.
- [x] Strict JWT authentication across all staff and student routes.
- [x] Role-Based Access Control (RBAC): Faculty Mentors and T&P Officers isolated from unauthorized role escalation.
- [x] Connection pooling via PgBouncer / Supabase Pooler (`pool_mode=transaction`).
- [x] Healthcheck and request logging enabled on port `3000`.

