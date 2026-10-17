# Police CCTV Camera Mapping & Investigation System
## Comprehensive Repository Analysis & Mobile Development Plan

**Document Version:** 1.0.0  
**Target Platform:** Flutter Mobile Application (`mobile/`)  
**Existing Ecosystem:** Spring Boot 3.2 Backend + PostgreSQL/PostGIS + React 18 Web Frontend  
**Analysis Date:** October 2026  

---

## 1. Repository Architecture & Folder Responsibilities

```
CameraMappingSystem--main/
├── backend/                       # Spring Boot 3.2.4 REST API (Java 21)
│   ├── src/main/java/com/police/cameramapping/
│   │   ├── common/                # Shared ApiResponse<T>, GlobalExceptionHandler, exceptions
│   │   ├── config/                # DataSourceConfig, DatabaseSeeder, SecurityConfig
│   │   ├── controller/            # 7 REST Controllers (Auth, Camera, Case, Dashboard, Media, Health, CCTNS)
│   │   ├── domain/
│   │   │   ├── model/             # JPA Entities (Camera, Case, PoliceStation, User, Role, AuditLog, etc.)
│   │   │   └── repository/        # Spring Data Repositories (PostGIS spatial queries)
│   │   ├── dto/                   # Request & Response DTOs
│   │   ├── security/              # JWT Utilities, Filter, UserDetailsServiceImpl
│   │   └── service/               # Business services & seeders (Nagpur realistic dataset)
│   ├── src/main/resources/        # application.yml, application-dev.yml, schema.sql
│   ├── Dockerfile                 # Production Docker multi-stage build container
│   └── pom.xml                    # Maven build dependencies
│
├── frontend/                      # React 18 SPA (Vite + TailwindCSS)
│   ├── src/
│   │   ├── api/                   # Axios client with JWT interceptor & 401 handler
│   │   ├── components/            # CameraMap (Leaflet), 3D Map (Cesium/MapLibre), SurveyModal, DossierModal
│   │   ├── context/               # AuthContext (login, logout, roles)
│   │   └── pages/                 # Dashboard, CameraList, InvestigationView, VerificationQueue, MyFieldSurveys
│   ├── package.json               # Node dependencies
│   └── vite.config.js             # Vite dev server with /api proxy to localhost:8088
│
├── mobile/                        # Newly initialized Flutter project
│   ├── lib/                       # Flutter Dart application code (currently default counter template)
│   ├── android/                   # Android native wrapper
│   ├── ios/                       # iOS native wrapper
│   ├── pubspec.yaml               # Flutter dependencies (cupertino_icons, flutter_lints)
│   └── analysis_options.yaml      # Dart static analysis rules
│
├── render.yaml                    # Render Blueprint orchestrating DB, Backend, and Frontend
├── DEPLOYMENT.md                  # Deployment guide & credentials overview
├── DESIGN (3).md                  # Mastercard-inspired editorial design system guidelines
├── README.md                      # High-level architecture overview
└── .env.example                   # Backend environment configuration template
```

---

## 2. Existing Web Application Functionality & User Roles

### User Roles & Permissions Matrix

| Permission / Feature | `ROLE_ADMIN` | `ROLE_POLICE_OFFICER` | `ROLE_SURVEY_PERSON` |
|---|:---:|:---:|:---:|
| **Login & JWT Token Retrieval** | ✅ | ✅ | ✅ |
| **System Dashboard KPI Stats** | ✅ | ❌ *(Hidden in UI)* | ❌ *(Hidden in UI)* |
| **View Camera Map & Directory** | ✅ | ✅ | ✅ |
| **View Camera Technical Dossier** | ✅ | ✅ | ✅ |
| **Survey & Register New Camera** | ✅ *(Auto-Approved)* | ✅ *(Pending Approval)* | ✅ *(Pending Approval)* |
| **Check Serial / Code Duplicate** | ✅ | ✅ | ✅ |
| **Owner Contact Summary Lookup** | ✅ | ✅ | ✅ |
| **Camera Verification Queue** | ✅ *(Approve / Reject)* | ❌ *(403 in UI)* | ❌ *(403 in UI)* |
| **View / Manage My Field Surveys**| ❌ *(UI redirects)* | ❌ *(UI redirects)* | ✅ |
| **Create Investigation Case** | ✅ | ✅ | ❌ *(403 in UI)* |
| **Auto-Match Radius Cameras (GIS)**| ✅ | ✅ | ❌ |
| **Attach Camera Evidence to Case** | ✅ | ✅ | ❌ |
| **CCTNS Sync Trigger** | ✅ *(Backend ready)* | ❌ | ❌ |

### Authentication & Token Lifecycle
1. **Login Flow**:
   - `POST /api/v1/auth/login` receives `{ username, password }`.
   - Backend authenticates via `DaoAuthenticationProvider` and BCrypt.
   - Returns `ApiResponse<JwtResponse>` with `token` (access token, 24-hour expiration), `refreshToken` (7-day expiration), and user profile data (`id`, `username`, `email`, `fullName`, `role`, `policeStationId`, `policeStationName`).
2. **Frontend Storage**:
   - Web frontend stores `token` and `user` object in browser `localStorage`.
   - **Crucial finding**: Frontend **completely discards the `refreshToken`**! It is not saved in `localStorage`, nor is automatic silent token refresh implemented.
3. **Session Expiry & Logout**:
   - `axios.js` intercepts all 401 responses: it clears `localStorage` and forces a hard redirect to `/login`.
   - Logout is 100% client-side (clears `localStorage`). JWTs are stateless with no token blacklist in Redis/database.

### Real Web Features Deep-Dive
- **Interactive Geospatial Map (`CameraMap.jsx`)**:
  - Uses `react-leaflet` with CartoDB Voyager tiles (`https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png`) over OpenStreetMap data. **No Google Maps API key is required for 2D mapping.**
  - Renders directional camera wedges based on `directionAngle` and `fovAngle` using custom polygon calculations.
  - Color-codes camera markers: Green (Approved Active), Yellow (Pending Verification), Red (Offline/Inactive).
  - Also includes a 3D mode via `ThreeDMap.jsx` using Cesium / MapLibre GL.
- **Survey Registration Modal (`SurveyRegistrationModal.jsx`)**:
  - Captures GPS coordinates via browser `navigator.geolocation` or by clicking directly on the map.
  - Performs live duplicate checks on serial numbers and camera codes via `/cameras/check-duplicate`.
  - Performs owner contact lookup via `/cameras/owner-lookup` to auto-fill business/owner info.
  - Uploads camera snapshots via `POST /media/upload`.
  - Auto-generates a QR code URL via `api.qrserver.com`.
- **Verification Queue (`VerificationQueue.jsx`)**:
  - Admin view filtering cameras by `verificationStatus=PENDING`.
  - One-click approve or reject with mandatory rejection reason (`PATCH /cameras/{id}/approval`).
- **Investigation Workspace (`InvestigationView.jsx`)**:
  - Police officers create cases specifying crime location (GPS/map pin), title, crime type, incident date, and search radius (default 500m).
  - Backend executes native PostGIS `ST_DWithin` spatial query to discover all cameras within radius and auto-attaches them as case evidence nodes.
  - Officers inspect attached cameras, record footage time windows, and mark key evidence.

---

## 3. Backend API Inventory & Mobile Readiness

All endpoints are prefixed with `/api/v1`. Every endpoint wraps data in `ApiResponse<T>` (`{ success, message, data, errors, timestamp }`) except `/health` and local media download.

| Endpoint | Method | Purpose | Auth / Role | Mobile Readiness | Limitations, Risks & Notes |
|---|:---:|---|---|:---:|---|
| `/auth/login` | POST | Authenticate user & issue JWT | Public | **Ready** | Returns `token` and `refreshToken`. |
| `/auth/register` | POST | Register officer / surveyor | Public | **Ready** | Role must be specified (`ROLE_POLICE_OFFICER` or `ROLE_SURVEY_PERSON`). |
| `/auth/refresh` | POST | Rotate expired access token | Public | **Ready** | DTO expects `{ "refreshToken": "..." }`. Web app doesn't use it, but mobile should! |
| `/health` | GET | Liveness health probe | Public | **Ready** | Returns `{ status: "UP", timestamp: "..." }`. |
| `/dashboard/stats` | GET | KPI aggregates | Authenticated | **Ready** | Returns counts for active/offline/pending cameras, stations, cases. |
| `/cameras` | GET | Paginated camera list | Authenticated | **Ready** | Query params: `page`, `size`, `sortBy`, `sortDir`. |
| `/cameras/{id}` | GET | Get single camera by ID | Authenticated | **Ready** | Returns full technical and geospatial dossier. |
| `/cameras/code/{code}` | GET | Get camera by unique code | Authenticated | **Ready** | Ideal for QR code scan lookup. |
| `/cameras/search` | GET | Multi-parameter camera filter | Authenticated | **Ready** | Filters by query, area, type, status, verification status. |
| `/cameras/nearby` | GET | PostGIS proximity search | Authenticated | **Ready** | Params: `latitude`, `longitude`, `radiusMeters`. Returns distance in meters. |
| `/cameras/owner-lookup` | GET | Search owner existing cameras | `ADMIN`, `SURVEYOR`, `OFFICER` | **Ready** | Sanitizes contact to last 10 digits; returns count of approved/pending. |
| `/cameras/check-duplicate`| GET | Pre-registration check | `ADMIN`, `SURVEYOR`, `OFFICER` | **Ready** | Checks `serialNumber` or `cameraCode`. |
| `/cameras` | POST | Register surveyed camera | `ADMIN`, `SURVEYOR`, `OFFICER` | **Ready** | Admin entries auto-approved; surveyor entries set to `PENDING`. |
| `/cameras/{id}` | PUT | Update camera parameters | `ADMIN`, `SURVEYOR` | **Ready** | Updates coordinates, lens angles, address. |
| `/cameras/{id}/approval` | PATCH | Approve or reject camera | `ROLE_ADMIN` | **Ready** | Body: `{ "verificationStatus": "APPROVED"\|"REJECTED", "rejectionReason": "..." }`. |
| `/cameras/{id}` | DELETE | Soft-delete camera | `ROLE_ADMIN` | **Ready** | Sets `is_deleted = true`. |
| `/investigations` | POST | Open case & link radius cameras| `ADMIN`, `OFFICER`, `SURVEYOR` | **Ready** | Auto-discovers and attaches nearby cameras via PostGIS. |
| `/investigations` | GET | Paginated investigation cases | `ADMIN`, `OFFICER` | **Ready** | Sorted by creation date descending. |
| `/investigations/{id}` | GET | Get case details & cameras | Authenticated | **Ready** | Contains attached camera list with evidence notes. |
| `/investigations/number/{num}`| GET | Get case by unique number | Authenticated | **Ready** | Direct case lookup. |
| `/investigations/{id}/cameras`| POST | Attach camera evidence note | `ADMIN`, `OFFICER` | **Ready** | Body: `CaseCameraAttachRequest`. |
| `/investigations/{id}` | DELETE | Soft-delete investigation case | `ADMIN`, `OFFICER` | **Ready** | Sets `is_deleted = true`. |
| `/media/upload` | POST | Upload camera site photo | Public (`permitAll()`) | **Ready** | Multipart `file`. Returns Supabase URL or local relative path `/api/v1/media/...`. |
| `/media/{fileName}` | GET | Serve local fallback photo | Public | **Ready** | Streams image file. |
| `/cctns/sync-status` | GET | CCTNS integration status | Authenticated | **Ready** | Returns mock national police network telemetry. |
| `/cctns/sync-stations` | POST | Trigger CCTNS sync | Authenticated | **Ready** | Mock sync response. |
| `/cameras/reseed-nagpur-50` | POST | Reset & seed 50 cameras | Authenticated | **DESTRUCTIVE / RISK** | **Purges all cameras!** Missing method security annotation. |
| `/investigations/seed-nagpur`| POST | Reset & seed 8 cases | Public (`permitAll()`) | **CRITICAL RISK** | **Purges all cases without any authentication!** |

---

## 4. Database Architecture & Environment Configuration

### Database Technology & Spatial Extensions
- **RDBMS**: PostgreSQL (version 15 or 16).
- **Spatial Extension**: **PostGIS** is mandatory.
- **ORM / Spatial Layer**: Hibernate Spatial 6 + JTS Geometry (`org.locationtech.jts.geom.Point`).
- **Spatial Columns**:
  - `cameras.location_geom`: `geometry(Point, 4326)` (SRID 4326 = WGS84 standard GPS).
  - `investigation_cases.crime_location_geom`: `geometry(Point, 4326)`.
  - `police_stations.location_geom`: `geometry(Point, 4326)`.
- **Spatial Native Query**: Proximity searches execute `ST_DWithin(CAST(c.location_geom AS geography), CAST(ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS geography), :radiusMeters)` and compute distance using `ST_DistanceSphere`. Without PostGIS, the backend fails to boot or queries crash.

### Database Connection Resolution (`DataSourceConfig.java`)
The application inspects environment variables in this order:
1. `DATABASE_URL`: Cloud provider URI string (e.g. Render, Railway, Supabase) in format `postgresql://user:password@host:port/database` or `postgres://...`. `DataSourceConfig` parses the URI, extracts username and password, converts it to JDBC format `jdbc:postgresql://host:port/database`, and initializes HikariCP.
2. `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`: Standard Spring Boot properties.
3. Fallback default: `jdbc:postgresql://localhost:5432/cameramapping` (user `postgres`, pass `postgres`).
4. **Auto-PostGIS Check**: On boot, `DataSourceConfig.java` runs `CREATE EXTENSION IF NOT EXISTS postgis;` automatically.

### Database Schema Management & Migrations
- **JPA DDL Mode**: Driven by `JPA_DDL_AUTO` (defaults to `update` in dev and Render, `validate` recommended in prod).
- **Migration Tools**: **No Flyway or Liquibase migrations exist in this repository.** Tables are generated and updated automatically by Hibernate JPA reflection on `@Entity` classes.
- `schema.sql` contains only a placeholder comment.

### Distinguishing Local Dev vs Deployed Production
- **Local Dev**: Runs on local PostgreSQL with PostGIS extension enabled manually or via Docker container (`postgis/postgis:15-3.3`).
- **Render Production**: `render.yaml` provisions a managed PostgreSQL service `cameramapping-db` on the free tier and automatically wires `DATABASE_URL` over Render's internal private network.
- **Supabase Alternative**: The README mentions Supabase. Supabase provides PostgreSQL with PostGIS pre-enabled. If `DATABASE_URL` is pointed to Supabase pooler/direct connection, the backend connects without changes.

---

## 5. How Web and Mobile Share the Exact Same Data

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│         React Web App           │       │       Flutter Mobile App        │
│    (Vite / Tailwind / Leaflet)  │       │       (iOS / Android Native)    │
└────────────────┬────────────────┘       └────────────────┬────────────────┘
                 │                                         │
                 │ HTTPS (JSON REST API + JWT Bearer)     │ HTTPS (JSON REST API + JWT Bearer)
                 ▼                                         ▼
┌───────────────────────────────────────────────────────────────────────────┐
│             Unified Spring Boot 3.2 Backend Service                       │
│                   (/api/v1/auth, /cameras, /investigations)              │
└─────────────────────────────────────┬─────────────────────────────────────┘
                                      │
                                      │ JDBC / HikariCP
                                      ▼
┌───────────────────────────────────────────────────────────────────────────┐
│               Single Shared PostgreSQL Database + PostGIS                │
│             (Tables: cameras, investigation_cases, users, etc.)           │
└───────────────────────────────────────────────────────────────────────────┘
```

### Real Operation Synchronization Scenarios
1. **Camera Registration from Mobile**:
   - Field surveyor on mobile captures camera GPS, fills details, and sends `POST /api/v1/cameras`.
   - Spring Boot saves the camera record in the PostgreSQL `cameras` table with `verificationStatus = PENDING`.
   - The React web app (which polls `/cameras/search?verificationStatus=PENDING` every 3 seconds via TanStack Query) immediately shows the new camera in the admin's **Verification Queue** without any manual database sync.
2. **Admin Verification from Web**:
   - Admin on web clicks "Approve" (`PATCH /api/v1/cameras/{id}/approval`).
   - The status updates to `APPROVED` in PostgreSQL.
   - On the mobile app, when the surveyor refreshes "My Field Surveys" or views the map, the camera turns green and displays `APPROVED`.
3. **Police Investigation Linkage**:
   - Police officer on web creates an investigation (`POST /api/v1/investigations`).
   - The backend runs `ST_DWithin` in PostGIS and links nearby cameras into `case_cameras`.
   - An officer on mobile opening the same case sees the exact same linked cameras, incident coordinates, and evidence notes.

### Client-to-Backend Connectivity & Addressing Rules
- **Direct DB Access Forbidden**: Neither web nor mobile connects directly to PostgreSQL port 5432. All access goes through the Spring Boot REST API.
- **Production Base URL**: Both web and mobile use the same deployed backend URL (e.g. `https://cameramapping-api.onrender.com/api/v1`).
- **Local Development Addressing**:
  | Environment | Host Address to Reach Local Spring Boot Backend | Reason |
  |---|---|---|
  | **React Web (Local)** | `http://localhost:8088/api/v1` or `/api/v1` (via Vite proxy) | Runs in host browser |
  | **Android Emulator** | `http://10.0.2.2:8088/api/v1` | `localhost` in emulator points to Android virtual OS itself |
  | **iOS Simulator** | `http://127.0.0.1:8088/api/v1` | Shares Mac loopback network |
  | **Physical Phone (USB/WiFi)**| `http://<YOUR_LAN_IP>:8088/api/v1` (e.g. `192.168.1.50:8088`) | Must be on the same local Wi-Fi |

---

## 6. Missing APIs, Security Concerns & Technical Blockers

### ⚠️ Critical Security Vulnerabilities in Current Code
1. **Unauthenticated Case Deletion & Reset (`/investigations/seed-nagpur`)**:
   - Configured in `SecurityConfig.java` as `.permitAll()`.
   - Anyone on the public internet can send `POST /api/v1/investigations/seed-nagpur` to **wipe all police investigations** and reset them to the seeder defaults.
   - *Required Fix*: Restrict to `hasRole('ADMIN')` or disable in production.
2. **Unrestricted Camera Reseeding (`/cameras/reseed-nagpur-50`)**:
   - In `CameraController.java`, this endpoint has **no `@PreAuthorize` annotation**.
   - Any authenticated surveyor can call it to wipe all registered cameras and replace them with the 50 sample cameras.
   - *Required Fix*: Add `@PreAuthorize("hasRole('ADMIN')")`.
3. **Default JWT Secret in Repository**:
   - `application.yml` lines 44 and `application-dev.yml` line 18 define fallback dummy JWT secrets. If a deployment does not inject `JWT_SECRET`, tokens can be forged.
   - *Verification*: Ensure production Render service has `JWT_SECRET` configured with a strong key.

### ⚠️ Discrepancies Between Docs and Code
- **Default Passwords**:
  - `DEPLOYMENT.md` says: `Admin@123`, `Officer@123`, `Surveyor@123`.
  - `DatabaseSeeder.java` actually seeds: `admin123`, `officer123`, `surveyor123`.
  - Anyone attempting to log into a freshly seeded database using `DEPLOYMENT.md` passwords will fail authentication.

### ⚠️ Missing Endpoints in Backend
1. **Missing Police Station Endpoint (`GET /stations`)**:
   - `Dashboard.jsx` calls `api.get('/stations')`. The endpoint does not exist anywhere in the backend (returns 404).
2. **Missing Surveyor Filter in `/cameras/search`**:
   - `CameraSearchFilter` does not have a `surveyorId` parameter, even though `CameraRepository` has `findBySurveyor_IdAndIsDeletedFalse`. The web app currently fetches all 1000 cameras and filters client-side. Adding `surveyorId` to `CameraSearchFilter` would significantly optimize mobile bandwidth.
3. **Missing User Management Controller**:
   - `SecurityConfig` contains `.requestMatchers("/users/**").hasRole("ADMIN")`, but no `UserController` exists.
4. **Dormant JPA Entities**:
   - `AuditLog`, `Notification`, and `SurveyAssignment` entities and repositories exist, but have **no service logic, no controllers, and no UI**.

### ⚠️ Media Upload Handling on Mobile
- When Supabase credentials are not configured, `MediaController` saves images to the backend's local `uploads/cameras/` folder and returns a relative URL: `/api/v1/media/<filename>`.
- The web app handles this because browser images resolve relative to current host.
- In Flutter, `Image.network('/api/v1/media/...')` will throw an error. The mobile app must detect relative paths and prepend the active `baseUrl`.

---

## 7. Requirements & Decisions Needed Before Development

| # | Item | Category | Action / Clarification Needed |
|---|---|---|---|
| 1 | **Deployed Backend Reachability** | Production Verification | Confirm if `https://cameramapping-api.onrender.com` is actively deployed, awake, and reachable via `/health`. |
| 2 | **Database in Production** | Production Verification | Confirm whether production uses Render Managed PostgreSQL, Supabase, or another provider. |
| 3 | **Media Storage Mode** | Confirmation from User | Will live camera photos use Supabase Cloud Storage or local disk fallback? (Affects image URL handling). |
| 4 | **Map Tile Choice** | Local Config / Ready | Use OpenStreetMap / CartoDB Voyager tiles (100% free, no API keys, matches web app) vs Google Maps SDK (requires Google Cloud API key). |
| 5 | **Mobile Roles & Scope** | User Decision | Should the mobile app support all 3 roles (Surveyor, Officer, Admin), or focus primarily on Field Surveyor & Patrol Officer first? |
| 6 | **Dev Environment Setup** | Local Config | Test with Android Emulator (`10.0.2.2:8088`), iOS Simulator, or physical device on Wi-Fi? |
| 7 | **Backend Security Patch** | Requires Backend Changes | Authorize adding `@PreAuthorize("hasRole('ADMIN')")` to destructive `/cameras/reseed-nagpur-50` and removing `/investigations/seed-nagpur` from `permitAll()`. |

---

## 8. Recommended Flutter Architecture & Packages

### Package Selection (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # Networking & REST
  dio: ^5.4.1                      # HTTP client with interceptors, timeouts, multipart
  pretty_dio_logger: ^1.3.1        # Formatted API logs in debug mode

  # State Management
  flutter_riverpod: ^2.5.1         # Declarative, testable state management

  # Secure Storage & Persistence
  flutter_secure_storage: ^9.0.0   # Keychain / KeyStore for JWT access & refresh tokens
  shared_preferences: ^2.2.2       # Non-sensitive app preferences (base URL, theme)

  # Geospatial & Maps
  flutter_map: ^6.1.0              # Fast Leaflet-like map engine for OpenStreetMap / CartoDB
  latlong2: ^0.9.0                 # Latitude/Longitude calculations & coordinate objects
  geolocator: ^11.0.0              # Device GPS live positioning

  # Device Hardware: Camera & QR
  image_picker: ^1.0.7             # Capture photo or pick from gallery
  mobile_scanner: ^5.0.0           # Camera QR-code barcode reader for camera tags

  # UI, Icons & Polish
  google_fonts: ^6.1.0             # Sofia Sans / Inter typography matching web
  intl: ^0.19.0                    # Date, time & currency formatting
  cached_network_image: ^3.3.1     # Smooth cached image loading
  flutter_spinkit: ^5.2.0          # Elegant loading spinners
```

### Clean Architecture Directory Layout

```
mobile/lib/
├── core/
│   ├── config/
│   │   ├── app_config.dart        # Base URLs (local emulator, LAN, production)
│   │   └── theme.dart             # Mastercard-inspired theme (Cream, Ink Black, Signal Orange)
│   ├── constants/
│   │   ├── api_endpoints.dart     # All backend REST endpoint paths
│   │   └── app_colors.dart        # Hex palette tokens
│   ├── network/
│   │   ├── api_client.dart        # Dio setup with logging & timeouts
│   │   ├── auth_interceptor.dart  # Bearer token injection & automatic 401 token refresh
│   │   └── error_handler.dart     # Maps HTTP errors & ApiException to user messages
│   └── storage/
│       └── secure_storage.dart    # Token & user profile storage
│
├── features/
│   ├── auth/
│   │   ├── data/                  # AuthRepository, AuthRemoteDataSource
│   │   ├── models/                # User, LoginRequest, JwtResponse
│   │   ├── providers/             # auth_provider.dart (login, logout, session check)
│   │   └── presentation/          # LoginScreen, RegisterScreen
│   │
│   ├── dashboard/
│   │   ├── data/                  # DashboardRepository
│   │   ├── models/                # AnalyticsStats
│   │   └── presentation/          # DashboardScreen (KPI summary, quick actions)
│   │
│   ├── map/
│   │   ├── presentation/          # CameraMapScreen (flutter_map, camera markers, FOV wedges)
│   │   └── widgets/               # CameraMarker, FovWedgePainter, CompassWidget
│   │
│   ├── camera/
│   │   ├── data/                  # CameraRepository (search, nearby, duplicate check)
│   │   ├── models/                # CameraModel, CameraCreateRequest, OwnerSummary
│   │   ├── providers/             # camera_list_provider, camera_detail_provider
│   │   └── presentation/
│   │       ├── camera_list_screen.dart
│   │       ├── camera_detail_screen.dart
│   │       ├── survey_registration_screen.dart   # Camera, GPS, Photo, Serial check
│   │       ├── qr_scanner_screen.dart            # Scan camera code
│   │       └── verification_queue_screen.dart    # Admin approve/reject
│   │
│   └── investigation/
│       ├── data/                  # InvestigationRepository
│       ├── models/                # CaseModel, CaseCamera, CaseCreateRequest
│       ├── providers/             # investigation_provider.dart
│       └── presentation/
│           ├── case_list_screen.dart
│           ├── case_detail_screen.dart
│           └── new_case_screen.dart               # GPS crime scene & auto-radius
│
└── main.dart                      # App entry point, Riverpod ProviderScope, routing
```

---

## 9. Phased Mobile Implementation Plan

```
Phase 1: Foundation (Network, Tokens, Mastercard Theme)
   │
Phase 2: Auth Flow (Login, Secure Storage, Role Session)
   │
Phase 3: Interactive Map & Live GPS (flutter_map + CartoDB)
   │
Phase 4: Field Survey Workflow (Camera Photo, GPS, QR, Duplicate Check)
   │
Phase 5: Camera Directory & Detailed Dossier
   │
Phase 6: Police Officer Investigation Workspace (Case Creation & Radius Discovery)
   │
Phase 7: Admin Verification Queue & Approvals
   │
Phase 8: Offline Caching, Hardening & End-to-End Verification with Web
```

### Phase Details

#### Phase 1: Environment & Network Foundation
- Implement `AppConfig` supporting seamless toggling between **Local Backend** (`10.0.2.2:8088` for Android, `localhost:8088` for iOS) and **Production Backend** (`https://cameramapping-api.onrender.com/api/v1`).
- Configure `Dio` HTTP client with:
  - Base headers (`Content-Type: application/json`).
  - Request interceptor attaching `Authorization: Bearer <token>`.
  - Response interceptor catching 401s and attempting token rotation via `POST /auth/refresh` before redirecting to login.
- Implement design tokens matching `DESIGN (3).md`:
  - Canvas Cream (`#F3F0EE`), Ink Black (`#141413`), Signal Orange (`#CF4500`).
  - Pill stadiums (`BorderRadius.circular(999)` and `20.0`).

#### Phase 2: Authentication & Role Gate
- Implement `LoginScreen` matching web login credentials and layout.
- Save access token, refresh token, and user role in `flutter_secure_storage`.
- Gate features by role: Surveyors see Surveying + Map; Officers see Investigations + Map; Admins see All + Verification.

#### Phase 3: Interactive Map & Live GPS Positioning
- Implement `flutter_map` using OpenStreetMap CartoDB Voyager tiles.
- Integrate `geolocator` to locate the field user and center the map.
- Render camera markers with status colors (Green = Approved, Orange = Pending, Red = Offline).
- Tap marker to open Camera Bottom Sheet.

#### Phase 4: Field Camera Survey & Registration Flow
- Multi-step survey screen matching `SurveyRegistrationModal.jsx`:
  1. GPS Location capture (device live fix or tap-on-map coordinate picker).
  2. Camera identification (Serial Number duplicate check, Camera Code generation).
  3. Owner mobile lookup (auto-fills owner name and shows previously registered cameras).
  4. Photo capture (`image_picker`) and upload to `POST /media/upload`.
  5. Direction & coverage angle inputs (Cardinal direction, FOV slider).
- Submission to `POST /cameras` with immediate feedback.

#### Phase 5: Camera Directory & Technical Dossier
- Search bar querying `GET /cameras/search?query=...`.
- Filter chips: Camera Type (PTZ, Dome, Bullet, ANPR) and Camera Status.
- Full Camera Dossier modal showing installation date, address, owner contact, and QR code.

#### Phase 6: Police Officer Investigation Workspace
- Case creation screen: Crime location GPS, title, crime type, incident timestamp, search radius slider (100m - 2000m).
- `POST /investigations` call triggers automatic PostGIS radius matching on backend.
- Detailed case view showing auto-discovered CCTV cameras on a map with distance badges.
- Footage request note recorder (`POST /investigations/{id}/cameras`).

#### Phase 7: Admin Verification Queue
- List pending cameras (`GET /cameras/search?verificationStatus=PENDING`).
- Review photos, GPS coordinates, and surveyor notes.
- Quick Approve (`PATCH /cameras/{id}/approval` with `status: APPROVED`) or Reject with reason modal.

#### Phase 8: Verification & Cross-Platform Testing
- Verify that a camera surveyed on mobile instantly appears in the React web dashboard.
- Verify that an approval made on the web instantly updates status on mobile.
- Verify error handling when device is offline.

---

## 10. Final Readiness Assessment

| Area | Status | Notes & What Must Be Done |
|---|:---:|---|
| **Backend API Core Endpoints** | ✅ **READY** | All required CRUD, search, proximity, auth, and upload endpoints exist and function. |
| **Database & PostGIS Queries** | ✅ **READY** | Schema, spatial entities, and native PostGIS queries are fully implemented in Hibernate. |
| **Web Application State** | ✅ **READY** | Fully functioning React SPA with working maps, modals, and query hooks. |
| **Mobile Scaffolding** | ✅ **READY** | Flutter project initialized in `mobile/`. |
| **Deployed Production Backend** | ⚠️ **UNVERIFIED** | Needs confirmation if `https://cameramapping-api.onrender.com` is live and healthy. |
| **Media Storage Configuration** | ⚠️ **UNVERIFIED** | Needs confirmation whether Supabase bucket or local fallback is used in production. |
| **Backend Destructive Endpoint Protection** | ❌ **ACTION REQUIRED** | `/cameras/reseed-nagpur-50` and `/investigations/seed-nagpur` must be protected before production launch. |
| **Missing `/stations` Endpoint** | ⚠️ **LOW IMPACT** | Exists as an issue on the web frontend; mobile app can bypass this by reading station info directly from camera responses. |

---

*Analysis completed. Awaiting user authorization before modifying files or implementing the mobile application.*
