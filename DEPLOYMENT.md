# Render Deployment Guide — Police Camera Mapping System

This guide explains how to deploy the **Police Camera Mapping & Geospatial Surveillance System** to **[Render](https://render.com/)** with **zero exposed secrets or credentials on GitHub**.

---

## 🔒 Security Architecture (Zero GitHub Credential Exposure)

1. **No Hardcoded Secrets**: All passwords, database URLs, JWT tokens, and Supabase keys are provided strictly via environment variables.
2. **Git Protection**: All `.env`, `.env.*`, and local credential files are ignored by [`.gitignore`](./.gitignore).
3. **Automated Secret Generation**:
   - `JWT_SECRET` is automatically generated on Render using `generateValue: true` or set via the Render dashboard.
   - `DATABASE_URL` is securely wired over Render's private internal network via `fromDatabase: connectionString`.
   - PostGIS extension is auto-enabled on startup by the backend (`DataSourceConfig`).

---

## Method 1: Automatic Deployment with Render Blueprint (Recommended)

Render Blueprints allow you to deploy the Database, Backend API, and Frontend with a single click.

1. **Push your code to GitHub** (already done!).
2. Log into the **[Render Dashboard](https://dashboard.render.com/)**.
3. Click **New +** in the top-right and select **Blueprint**.
4. Connect your GitHub repository (`CameraMappingSystem-`).
5. Render will automatically detect the [`render.yaml`](./render.yaml) file:
   - **`cameramapping-db`**: Managed PostgreSQL database.
   - **`cameramapping-api`**: Docker Web Service running Spring Boot 3 on Java 21.
   - **`cameramapping-web`**: Static Site building the React Vite SPA with client-side SPA routing.
6. *(Optional)* If using Supabase Storage for camera photo uploads:
   - In the Blueprint setup page, provide your `SUPABASE_URL` and `SUPABASE_KEY` (service role key).
   - If left blank, the system automatically falls back to local media storage.
7. Click **Apply**.
8. Once the build completes, your system is live!

---

## Method 2: Manual Dashboard Deployment (Step-by-Step)

If you prefer configuring each service individually in the Render Dashboard:

### Step 1: Create the Managed PostgreSQL Database

1. Click **New +** → **PostgreSQL**.
2. Set **Name**: `cameramapping-db`
3. Set **Database**: `cameramapping`
4. Set **User**: Leave default (Render auto-generates a secure user) or use `cameramapping_user` (do NOT use reserved `postgres`)
5. Set **Region**: Choose closest to you (e.g., `Oregon (US West)` or `Frankfurt (EU)`).
6. Set **Plan**: `Free`.
7. Click **Create Database**.
8. Once provisioned, copy the **Internal Database URL** (e.g., `postgresql://postgres:password@dpg-...:5432/cameramapping`).

---

### Step 2: Deploy the Backend Web Service

1. Click **New +** → **Web Service**.
2. Connect your GitHub repository.
3. Configure the service:
   - **Name**: `cameramapping-api`
   - **Region**: Same region as your database.
   - **Branch**: `main`
   - **Root Directory**: `backend` (or leave blank if using Dockerfile path)
   - **Runtime**: `Docker`
   - **Dockerfile Path**: `backend/Dockerfile`
   - **Docker Context**: `backend`
   - **Instance Type**: `Free`
4. Add **Environment Variables**:

| Variable | Value | Notes |
| :--- | :--- | :--- |
| `SPRING_PROFILES_ACTIVE` | `prod` | Activates production configuration |
| `DATABASE_URL` | *(Paste Internal Database URL from Step 1)* | Render's PostgreSQL connection string |
| `JWT_SECRET` | *(Click "Generate" or use 64-char hex)* | Used to sign auth tokens |
| `JPA_DDL_AUTO` | `update` | Auto-creates schema & spatial tables on first boot |
| `APP_SEEDER_ENABLED` | `true` | Seeds stations, users, 50 Nagpur cameras & 8 cases |
| `CORS_ALLOWED_ORIGINS` | `https://<YOUR-FRONTEND-NAME>.onrender.com,http://localhost:3000` | Update once frontend is created |
| `SUPABASE_URL` | `https://your-project.supabase.co` | *(Optional: for cloud image storage)* |
| `SUPABASE_KEY` | `your-service-role-key` | *(Optional)* |
| `SUPABASE_BUCKET` | `camera-media` | *(Optional, default: camera-media)* |

5. Click **Create Web Service**.
6. Note down your backend URL (e.g., `https://cameramapping-api.onrender.com`).

---

### Step 3: Deploy the Frontend Static Site

1. Click **New +** → **Static Site**.
2. Connect your GitHub repository.
3. Configure the service:
   - **Name**: `cameramapping-web`
   - **Branch**: `main`
   - **Root Directory**: `frontend`
   - **Build Command**: `npm install && npm run build`
   - **Publish Directory**: `dist`
4. Add **Environment Variables**:

| Variable | Value | Notes |
| :--- | :--- | :--- |
| `VITE_API_URL` | `https://cameramapping-api.onrender.com/api/v1` | URL of the backend service from Step 2 |

5. Add **Redirects / Rewrites** (under Settings → Redirects/Rewrites):
   - **Source**: `/*`
   - **Destination**: `/index.html`
   - **Action**: `Rewrite` *(Essential for React Router SPA navigation on refresh)*
6. Click **Create Static Site**.
7. Once deployed, copy your frontend URL and ensure it is included in `CORS_ALLOWED_ORIGINS` on the backend service.

---

## 🔑 Default Prototype Credentials

When `APP_SEEDER_ENABLED=true` is set, the system automatically provisions initial accounts on the first run:

| Role | Username | Password | Access Level |
| :--- | :--- | :--- | :--- |
| **Admin** | `admin` | `Admin@123` | Full precinct control, approvals, camera dossier editing |
| **Field Officer** | `officer1` | `Officer@123` | Investigation GIS telemetry, camera radius analysis |
| **Field Surveyor** | `surveyor1` | `Surveyor@123` | Camera survey registration, QR verification, uploads |

---

## 🛡️ Pre-Flight Verification Checklist

- [x] `.env` and `backend/.env` are ignored by git (`git check-ignore -v .env`).
- [x] Backend dynamically binds to `${PORT}` supplied by Render.
- [x] Backend converts Render's `DATABASE_URL` format (`postgresql://...`) to `jdbc:postgresql://...` automatically via `DataSourceConfig.java`.
- [x] PostGIS spatial extension is verified on database initialization.
- [x] Frontend dynamically connects to backend via `VITE_API_URL` / `VITE_API_BASE_URL`.
- [x] Frontend Content Security Policy (CSP) permits `https://*.onrender.com`.
- [x] Frontend static site rewrite rule (`/* -> /index.html`) prevents 404 errors on page reload.
- [x] Zero API keys, passwords, or tokens are committed to GitHub.
