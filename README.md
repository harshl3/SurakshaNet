# 🚔 Police CCTV Camera Mapping & Investigation System

A full-stack enterprise platform for police departments to map CCTV cameras geospatially, conduct field surveys, manage investigation cases with automated camera proximity discovery (PostGIS), and maintain a multi-role secure workflow.

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| Backend | Spring Boot 3.2, Spring Security, JWT, JPA/Hibernate |
| Database | PostgreSQL + PostGIS (Supabase) |
| ORM | Hibernate Spatial, JTS Geometry |
| Frontend | React 18, Vite, TailwindCSS, React-Leaflet |
| Auth | JWT (Access + Refresh Tokens), BCrypt |
| Maps | Leaflet.js + OpenStreetMap |

---

## 👥 User Roles

| Role | Permissions |
|---|---|
| `ROLE_ADMIN` | Full access — approve/reject cameras, manage users, view all data |
| `ROLE_POLICE_OFFICER` | Create/manage investigation cases, view cameras |
| `ROLE_SURVEY_PERSON` | Field camera surveys only — cannot access investigations |

---

## 🚀 Getting Started

### Prerequisites

- Java 21+
- Maven 3.9+
- Node.js 18+
- PostgreSQL with PostGIS extension
- (Recommended) Supabase project

### 1. Clone the Repository

```bash
git clone https://github.com/shantanumangalkar/CameraMappingSystem-
cd CameraMappingSystem-
```

### 2. Configure Environment Variables

```bash
# Copy the example env file and fill in your values
cp .env.example .env
```

Edit `.env` with your actual database, JWT, and Supabase credentials. See `.env.example` for all required variables.

> ⚠️ **NEVER commit your `.env` file** — it is excluded by `.gitignore`.

### 3. Run the Backend

```bash
cd backend
./mvnw spring-boot:run
```

The API will be available at `http://localhost:8088/api/v1`

### 4. Run the Frontend

```bash
cd frontend
npm install
npm run dev
```

The UI will be available at `http://localhost:3000`

---

## 🔐 Security

- **JWT Authentication** — Stateless tokens with configurable expiry
- **Role-Based Access Control (RBAC)** — Method-level security with `@PreAuthorize`
- **BCrypt Password Hashing** — Strength factor 12
- **CORS** — Explicitly restricted to configured origins
- **HTTP Security Headers** — HSTS, X-Frame-Options, CSP, Referrer-Policy
- **No Secrets in Code** — All credentials must be supplied via environment variables
- **Swagger Gated** — API docs accessible to admins only (disabled by default in production)

### Generating a Secure JWT Secret

```bash
openssl rand -hex 32
```

---

## 📦 Environment Variables

See [`.env.example`](./.env.example) for the full list of required backend environment variables, and [`frontend/.env.example`](./frontend/.env.example) for frontend variables.

---

## 🗄️ Database Schema

The application uses PostgreSQL with the PostGIS extension. Key entities:

- **Camera** — CCTV camera with geospatial location, type, status, owner info
- **PoliceStation** — Law enforcement units with coordinates (CCTNS integrated)
- **InvestigationCase** — Police cases with automatic camera radius discovery
- **User** — Multi-role users (Admin / Officer / Surveyor)
- **AuditLog** — Full audit trail of all entity changes

### Setting up PostGIS

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

---

## 🛠️ API Documentation

Swagger UI is available to administrators only (requires JWT with ADMIN role):

```
http://localhost:8088/api/v1/swagger-ui.html
```

To enable in dev, set `SWAGGER_ENABLED=true` (enabled automatically with `dev` profile).

---

## 🏭 Production Deployment

1. Set `SPRING_PROFILES_ACTIVE=prod` (disables the DatabaseSeeder)
2. Set `JPA_DDL_AUTO=validate` or `none`
3. Set `SWAGGER_ENABLED=false`
4. Use a strong `JWT_SECRET` (min 256-bit)
5. Configure `CORS_ALLOWED_ORIGINS` to your exact frontend domain

---

## 📝 License

This project is developed for law enforcement use. All rights reserved.
