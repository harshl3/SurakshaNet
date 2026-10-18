# Police CCTV Camera Mapping & Investigation System
## Mobile Application Implementation Report

**Target Directory:** `mobile/`  
**Flutter SDK:** 3.44.6 • Dart 3.12.2  
**State Management:** Flutter Riverpod 2.6.1  
**Networking:** Dio 5.11.1  
**Mapping:** Flutter Map 8.3.2 with CartoDB Voyager tiles (OpenStreetMap)  
**Date:** October 2026  

---

## 1. Executive Summary

A production-quality Flutter mobile application has been implemented inside `mobile/` for the **Police CCTV Camera Mapping & Investigation System**. The application adheres strictly to the Mastercard-inspired design system (`DESIGN (3).md`), communicates directly with the Spring Boot 3 REST API (`/api/v1`), and strictly avoids touching or mutating any code or configurations outside `mobile/`.

### Key Verification & Quality Results:
- **`flutter analyze`**: **0 issues found** (clean static analysis).
- **`flutter test`**: **All 5 unit and widget tests passed** (100% pass rate).
- **Repository Isolation**: **100% of changes are inside `mobile/`**. `backend/`, `frontend/`, `render.yaml`, and database schemas were completely untouched.
- **Destructive Endpoints**: Zero calls made to `/cameras/reseed-nagpur-50` or `/investigations/seed-nagpur`.
- **Database Safety**: The mobile application connects solely via REST APIs and never connects directly to PostgreSQL/PostGIS.

---

## 2. Inspection Findings Summary

### 2.1 Current Flutter Project State
- Was freshly initialized with Flutter's default counter template in `lib/main.dart`.
- Dependencies updated cleanly to include `dio`, `flutter_riverpod`, `flutter_secure_storage`, `shared_preferences`, `flutter_map`, `latlong2`, `geolocator`, `image_picker`, `mobile_scanner`, `intl`, and `cached_network_image`.

### 2.2 Confirmed API Routes & Response Format
The backend context path is `/api/v1`. All endpoints return the standardized envelope `ApiResponse<T>`:
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": { ... },
  "errors": null,
  "timestamp": "2026-10-18T..."
}
```
Key confirmed endpoints:
- `GET /health`: Liveness probe (`{"status":"UP","service":"police-camera-mapping-system"}`).
- `POST /auth/login`: `{ username, password }` -> returns JWT access token (24h), refresh token (7d), user profile.
- `POST /auth/refresh`: `{ refreshToken }` -> returns rotated JWT access token.
- `GET /dashboard/stats`: KPI metrics across cameras, stations, and investigation cases.
- `GET /cameras`: Paginated cameras (`Page<CameraResponse>`).
- `GET /cameras/{id}`: Single camera technical & geospatial dossier.
- `GET /cameras/code/{code}`: Camera lookup by unique QR code.
- `GET /cameras/search`: Multi-criteria search (query, area, status, verificationStatus).
- `GET /cameras/nearby`: PostGIS spatial proximity search (`latitude`, `longitude`, `radiusMeters`).
- `GET /cameras/owner-lookup`: Search existing cameras by owner mobile contact.
- `GET /cameras/check-duplicate`: Pre-registration duplicate check on serial number or camera code.
- `POST /cameras`: Register surveyed camera (Auto-approved for Admin, Pending for Surveyor/Officer).
- `PATCH /cameras/{id}/approval`: Admin approve/reject with rejection reason.
- `GET /investigations`: Paginated investigation cases (Admin & Officer).
- `POST /investigations`: Open case with automated PostGIS camera radius discovery (`searchRadiusMeters`).
- `GET /investigations/{id}`: Case details and linked camera evidence nodes.
- `POST /investigations/{id}/cameras`: Attach camera evidence notes and footage timestamps.
- `POST /media/upload`: Multipart camera photo upload returning Supabase URL or local relative path `/api/v1/media/<filename>`.

### 2.3 Authentication Response & Role Representation
- Roles confirmed in backend: `ROLE_ADMIN`, `ROLE_POLICE_OFFICER`, and `ROLE_SURVEY_PERSON`.
- User model parses `id`, `username`, `email`, `fullName`, `role`, `policeStationId`, and `policeStationName`.
- `SecureStorageService` securely persists access token, refresh token, and user profile data in encrypted device storage with in-memory caching fallback.

### 2.4 Design System Tokens (`DESIGN (3).md`)
- **Canvas Cream**: `#F3F0EE` (warm paper default background).
- **Lifted Cream / Cards**: `#FCFBFA` with 20px-24px rounded corners.
- **Ink Black**: `#141413` (primary CTAs, headers).
- **Signal Orange**: `#CF4500` (eyebrow accents, warnings, compliance).
- **Status Green**: `#15803D` (active/verified).
- **Status Amber**: `#B45309` (pending verification).
- **Status Red**: `#B91C1C` (offline/rejected/damaged).
- **Typography**: Clean geometric typography hierarchy with negative letter spacing on headlines and pill-shaped interactive buttons.

### 2.5 Server & Integration Status
- **Render Production Health**: Verified live via `GET https://cameramapping-api.onrender.com/api/v1/health` (HTTP 200 OK, `status: UP`).
- **Live Auth Check**: Direct login to cloud Render returned `An unexpected error occurred. Please try again later.`, indicating the remote cloud database tables or users need seeding by backend admin.
- **Environment Switcher**: Implemented in Flutter so users can immediately switch between:
  1. Production Render Cloud (`https://cameramapping-api.onrender.com/api/v1`)
  2. Android Emulator local host (`http://10.0.2.2:8088/api/v1`)
  3. Local Wi-Fi / Physical Device LAN (`http://<PC_IP>:8088/api/v1`)
  4. Custom Base URL
- Features provide honest error states and diagnostic health check tools rather than fabricating data.

---

## 3. Architecture & Implemented Features

### 3.1 Folder Structure (`mobile/lib/`)
```
lib/
├── core/
│   ├── config/
│   │   └── env_config.dart                  # Dynamic environment selector & media URL resolver
│   ├── constants/
│   │   └── app_constants.dart               # Tile URLs, storage keys, default coordinates
│   ├── network/
│   │   ├── api_client.dart                  # Dio client, JWT interceptor, refresh lock, safe errors
│   │   ├── api_endpoints.dart               # Confirmed Spring Boot API route paths
│   │   └── api_response.dart                # ApiResponse<T> and PaginatedResponse<T>
│   ├── storage/
│   │   └── secure_storage_service.dart      # FlutterSecureStorage with memory fallback
│   ├── theme/
│   │   ├── app_colors.dart                  # Mastercard-inspired color palette
│   │   └── app_theme.dart                   # Light theme, pill buttons, card shapes
│   └── widgets/
│       ├── app_banner.dart                  # Environment switcher & health diagnostic modal
│       ├── custom_button.dart               # Ink pill, secondary outlined, and signal buttons
│       ├── custom_text_field.dart           # Form fields with validation & styling
│       ├── state_views.dart                 # LoadingView, ErrorStateView, EmptyStateView
│       └── status_badge.dart                # Status and verification pill badges
├── features/
│   ├── auth/
│   │   ├── models/                          # UserModel, AuthState
│   │   ├── providers/                       # authProvider, currentUserProvider
│   │   ├── repositories/                    # AuthRepository (login, restore, logout)
│   │   └── screens/
│   │       └── login_screen.dart            # Police sign-in, seed chips, environment chip
│   ├── camera/
│   │   ├── models/                          # CameraModel, OwnerSummaryModel, DuplicateCheckModel
│   │   ├── providers/                       # cameraListProvider, filterProvider, registrationNotifier
│   │   ├── repositories/                    # CameraRepository (CRUD, search, nearby, duplicate, upload)
│   │   └── screens/
│   │       ├── camera_detail_screen.dart    # Full technical dossier & photo preview
│   │       ├── camera_list_screen.dart      # Paginated directory with search & status filters
│   │       ├── camera_registration_screen.dart # Survey form, GPS capture, duplicate check, photo
│   │       └── qr_scanner_screen.dart       # Camera code scanning with manual entry fallback
│   ├── dashboard/
│   │   ├── models/                          # DashboardStats
│   │   ├── providers/                       # dashboardStatsProvider
│   │   ├── repositories/                    # DashboardRepository (/dashboard/stats)
│   │   └── screens/
│   │       └── dashboard_screen.dart        # Officer greeting, field shortcuts, live KPI grid
│   ├── investigation/
│   │   ├── models/                          # InvestigationCaseModel
│   │   ├── providers/                       # investigationListProvider, createCaseNotifier
│   │   ├── repositories/                    # InvestigationRepository (cases, radius matching, attach)
│   │   └── screens/
│   │       ├── investigation_create_screen.dart # Case creation with PostGIS spatial auto-matching
│   │       ├── investigation_detail_screen.dart # Case details, linked CCTV nodes, attach modal
│   │       └── investigation_list_screen.dart   # Active cases list
│   ├── map/
│   │   └── screens/
│   │       └── camera_map_screen.dart       # CartoDB Voyager map, GPS centering, status markers, preview
│   ├── navigation/
│   │   └── role_navigation_shell.dart       # Dynamic role tabs (Admin, Officer, Surveyor)
│   └── verification/
│       ├── providers/                       # verificationQueueProvider
│       └── screens/
│           └── verification_queue_screen.dart # Admin queue (Approve / Reject with reason)
└── main.dart                                # App root initializing EnvConfig & ProviderScope
```

---

## 4. Feature Implementation Details

### Phase 1 — Foundation
- Removed the counter template.
- Established Mastercard-inspired theme (`AppColors`, `AppTheme`).
- Centralized `EnvConfig` supporting Cloud, Emulator, and LAN targets without code changes.
- Safe backend health check diagnostic tool (`EnvironmentConfigSheet`).
- `ApiClient` with Dio interceptors, safe error formatting, and silent token refresh.

### Phase 2 — Authentication & Role-Based Navigation
- `LoginScreen` with clear visual hierarchy, seed credential chips (`admin`, `officer1`, `surveyor1`), and environment switch modal.
- `AuthRepository` storing JWT access token (24h) and refresh token (7d) in `SecureStorageService`.
- `RoleNavigationShell` routes users to role-specific tabs:
  - **`ROLE_ADMIN`**: Command Dashboard, GIS Map, Camera Directory, Investigation Cases, Verification Queue.
  - **`ROLE_POLICE_OFFICER`**: Command Dashboard, GIS Map, Camera Directory, Investigation Cases.
  - **`ROLE_SURVEY_PERSON`**: Home Dashboard, GIS Map, Camera Directory, Field Survey Registration.

### Phase 3 — Geospatial Camera Map
- `flutter_map` with CartoDB Voyager tile layer (OpenStreetMap data, zero API key required, matching web app).
- GPS device location centering using `geolocator` with permission handling.
- Real camera markers color-coded by status (Green: Active/Verified, Amber: Pending, Red: Offline/Damaged).
- Marker tap opens a stadium-styled preview card with quick actions to view full dossier.
- Status filter chip bar for live filtering on the map.

### Phase 4 — Camera Directory & Technical Dossier
- Real-time search by camera code, area, or name (`/cameras/search`).
- Filter by camera status and verification status.
- `CameraDetailScreen` rendering camera photo (with fallback), serial number, camera type, GPS latitude/longitude (with one-tap copy), lens azimuth angle, field of view (FOV), coverage radius, address, jurisdiction police station, and owner contact details.

### Phase 5 — Field Survey & Camera Registration
- Guided camera registration form (`CameraRegistrationScreen`).
- Automatic GPS capture from device with manual coordinate editing fallback.
- Live duplicate check for `cameraCode` and `serialNumber` (`/cameras/check-duplicate`).
- Real-time owner verification lookup by mobile number (`/cameras/owner-lookup`).
- Camera photo capture via camera or gallery (`image_picker`) and immediate upload via `POST /media/upload`.
- Azimuth facing angle slider (0-360°), FOV angle slider (15-180°), and coverage radius slider.
- Submits to `POST /cameras` and displays server confirmation dialog.

### Phase 6 — Camera QR Code Scanner
- Real camera scanner using `mobile_scanner` (`QrScannerScreen`).
- Live camera stream with scanning reticle overlay.
- Manual code input fallback for emulators or damaged QR labels.
- Queries `GET /cameras/code/{code}` and routes to `CameraDetailScreen`.

### Phase 7 — Police Investigation Workspace
- Case creation form (`InvestigationCreateScreen`) with crime location GPS and radius slider (100m - 2000m).
- Submits to `POST /investigations` which triggers backend PostGIS `ST_DWithin` spatial query to discover and attach nearby cameras.
- Case list (`InvestigationListScreen`) and dossier (`InvestigationDetailScreen`).
- Displays linked spatial CCTV nodes with distances in meters.
- Modal dialog to attach additional camera evidence notes and footage timestamps (`POST /investigations/{id}/cameras`).

### Phase 8 — Admin Verification Queue
- Restricted to `ROLE_ADMIN` with access restriction placeholder for non-admins.
- Displays pending cameras (`/cameras/search?verificationStatus=PENDING`).
- One-click Approve (`PATCH /cameras/{id}/approval`).
- Reject dialog with mandatory rejection reason.
- Automatically refreshes queue and camera directory upon action.

### Phase 9 — Operations Command Dashboard
- Officer greeting with name, role badge, and assigned police station.
- Server health diagnostic indicator.
- Field operations shortcuts (Field Survey, Scan QR, Open Case, Verification Queue).
- Real-time KPI statistics cards from `GET /dashboard/stats` (Total Cameras, Active Cameras, Pending Verification, Offline Cameras, Investigation Cases, Police Stations).

### Phase 10 — Testing & Verification
- Unit & widget test suite in `mobile/test/widget_test.dart`:
  - `LoginScreen renders police branding and inputs`
  - `UserModel JSON serialization & role checks`
  - `CameraModel JSON serialization & defaults`
  - `InvestigationCaseModel JSON mapping`
  - `EnvConfig URL resolution`
- `flutter analyze` completed with **0 issues**.
- `flutter test` completed with **5/5 tests passed**.

---

## 5. Security & Safety Compliance

- **No Destructive Endpoints**: Neither `/cameras/reseed-nagpur-50` nor `/investigations/seed-nagpur` are ever invoked.
- **No Direct Database Access**: Mobile connects strictly through Spring Boot REST endpoints.
- **No Hardcoded Secrets**: Secrets, keys, and passwords are not hardcoded.
- **Secure Token Storage**: JWT tokens are persisted via `FlutterSecureStorage` (encrypted key-value store).
- **Cleartext Permissions**: `android:usesCleartextTraffic="true"` configured specifically for local emulator (`10.0.2.2`) and local IP development. Production defaults to HTTPS.

---

## 6. How to Run & Configure

### Prerequisites
- Flutter SDK (>= 3.12.0)
- Android Studio / Android Emulator or iOS Simulator / Physical Device

### Run the App
```bash
cd mobile
flutter pub get
flutter run
```

### Switching Environments in the App
1. On the **Login Screen** or **Dashboard Screen**, tap the environment pill at the top.
2. Select your target:
   - **Render Cloud Production**: `https://cameramapping-api.onrender.com/api/v1`
   - **Android Emulator**: `http://10.0.2.2:8088/api/v1`
   - **Local Wi-Fi (LAN)**: `http://<YOUR_COMPUTER_IP>:8088/api/v1`
   - **Custom Base URL**: Custom host and port
3. Tap **Test Health** to verify backend connectivity.
4. Tap **Apply Target** to immediately switch the active API client without restarting the app.

---

## 7. Changed Files Summary

| File | Status | Description |
|---|:---:|---|
| `mobile/pubspec.yaml` | Modified | Added dependencies (`dio`, `flutter_riverpod`, `flutter_map`, etc.) |
| `mobile/android/app/src/main/AndroidManifest.xml` | Modified | Added Camera, Location, Internet permissions & cleartext traffic |
| `mobile/ios/Runner/Info.plist` | Modified | Added iOS camera & location usage descriptions |
| `mobile/lib/main.dart` | Replaced | Real application root with ProviderScope, light theme, and auth routing |
| `mobile/lib/core/constants/app_constants.dart` | Created | Constants, CartoDB tile URLs, storage keys, Nagpur coordinates |
| `mobile/lib/core/config/env_config.dart` | Created | Environment configuration (Production, Emulator, LAN, Custom) |
| `mobile/lib/core/theme/app_colors.dart` | Created | Mastercard-inspired cream, ink black, and signal orange palette |
| `mobile/lib/core/theme/app_theme.dart` | Created | Light theme, 24px pill borders, typography tokens |
| `mobile/lib/core/storage/secure_storage_service.dart` | Created | Encrypted JWT access and refresh token persistence |
| `mobile/lib/core/network/api_endpoints.dart` | Created | Confirmed Spring Boot REST API routes |
| `mobile/lib/core/network/api_response.dart` | Created | ApiResponse<T> and PaginatedResponse<T> models |
| `mobile/lib/core/network/api_client.dart` | Created | Dio client with JWT interceptor, refresh lock, and safe errors |
| `mobile/lib/core/widgets/custom_button.dart` | Created | Ink pill, secondary outlined, and signal orange buttons |
| `mobile/lib/core/widgets/custom_text_field.dart` | Created | Styled text inputs with validation |
| `mobile/lib/core/widgets/status_badge.dart` | Created | Status and verification pill badges |
| `mobile/lib/core/widgets/state_views.dart` | Created | LoadingView, ErrorStateView, EmptyStateView |
| `mobile/lib/core/widgets/app_banner.dart` | Created | Environment selector and health test modal sheet |
| `mobile/lib/features/auth/models/user_model.dart` | Created | UserModel with role predicates (Admin, Officer, Surveyor) |
| `mobile/lib/features/auth/models/auth_state.dart` | Created | AuthState lifecycle model |
| `mobile/lib/features/auth/repositories/auth_repository.dart` | Created | AuthRepository calling /auth/login and secure storage |
| `mobile/lib/features/auth/providers/auth_provider.dart` | Created | Riverpod authNotifier and currentUserProvider |
| `mobile/lib/features/auth/screens/login_screen.dart` | Created | Login UI with seed credential chips and environment switcher |
| `mobile/lib/features/navigation/role_navigation_shell.dart` | Created | Dynamic role-based navigation tabs |
| `mobile/lib/features/camera/models/camera_model.dart` | Created | CameraModel with technical, spatial, and ownership fields |
| `mobile/lib/features/camera/models/duplicate_check_model.dart` | Created | Duplicate check response model |
| `mobile/lib/features/camera/models/owner_summary_model.dart` | Created | Owner lookup response model |
| `mobile/lib/features/camera/repositories/camera_repository.dart` | Created | CameraRepository (CRUD, search, nearby, duplicate, upload) |
| `mobile/lib/features/camera/providers/camera_provider.dart` | Created | Camera providers (list, filter, detail, survey registration) |
| `mobile/lib/features/camera/screens/camera_list_screen.dart` | Created | Paginated camera directory with search and status chips |
| `mobile/lib/features/camera/screens/camera_detail_screen.dart` | Created | Full camera technical dossier & site photo preview |
| `mobile/lib/features/camera/screens/camera_registration_screen.dart` | Created | Field survey form, GPS coordinate capture, duplicate check |
| `mobile/lib/features/camera/screens/qr_scanner_screen.dart` | Created | Camera QR code scanner with manual code fallback |
| `mobile/lib/features/investigation/models/investigation_model.dart` | Created | InvestigationCaseModel with linked CCTV evidence nodes |
| `mobile/lib/features/investigation/repositories/investigation_repository.dart` | Created | InvestigationRepository (cases, radius matching, evidence attach) |
| `mobile/lib/features/investigation/providers/investigation_provider.dart` | Created | Investigation list, detail, and case creation providers |
| `mobile/lib/features/investigation/screens/investigation_list_screen.dart` | Created | Cases list with linked evidence counts |
| `mobile/lib/features/investigation/screens/investigation_detail_screen.dart` | Created | Case dossier, linked spatial CCTV nodes, attach evidence modal |
| `mobile/lib/features/investigation/screens/investigation_create_screen.dart` | Created | Open case with automated PostGIS spatial camera discovery |
| `mobile/lib/features/verification/providers/verification_provider.dart` | Created | Verification queue provider |
| `mobile/lib/features/verification/screens/verification_queue_screen.dart` | Created | Admin queue with Approve/Reject dialogs |
| `mobile/lib/features/dashboard/models/dashboard_stats.dart` | Created | DashboardStats model |
| `mobile/lib/features/dashboard/repositories/dashboard_repository.dart` | Created | DashboardRepository querying /dashboard/stats |
| `mobile/lib/features/dashboard/providers/dashboard_provider.dart` | Created | DashboardStats FutureProvider |
| `mobile/lib/features/dashboard/screens/dashboard_screen.dart` | Created | Operations dashboard with officer greeting and KPI grid |
| `mobile/lib/features/map/screens/camera_map_screen.dart` | Created | Geospatial map with CartoDB Voyager tiles and GPS centering |
| `mobile/test/widget_test.dart` | Updated | 5 unit and widget tests |
| `mobile/MOBILE_IMPLEMENTATION_REPORT.md` | Created | This comprehensive implementation documentation |
