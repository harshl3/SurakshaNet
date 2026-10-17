package com.police.cameramapping.controller;

import com.police.cameramapping.common.dto.ApiResponse;
import com.police.cameramapping.dto.camera.*;
import com.police.cameramapping.service.CameraService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/cameras")
@RequiredArgsConstructor
@Tag(name = "Camera Management & Geospatial GIS Module", description = "CCTV camera CRUD, spatial radius search, and approval queue")
public class CameraController {

    private final CameraService cameraService;
    private final com.police.cameramapping.service.NagpurCameraSeederService nagpurCameraSeederService;

    @PostMapping("/reseed-nagpur-50")
    @Operation(summary = "Purge existing cameras and reseed exactly 50 realistic Nagpur cameras")
    public ResponseEntity<ApiResponse<java.util.Map<String, Object>>> reseedNagpurCameras() {
        var cameras = nagpurCameraSeederService.reseed50NagpurCameras();
        java.util.Map<String, Object> result = new java.util.HashMap<>();
        result.put("totalCameras", cameras.size());
        result.put("city", "Nagpur");
        result.put("message", "Purged existing cameras and seeded 50 realistic cameras in Nagpur with complete parameters.");
        return ResponseEntity.ok(ApiResponse.success(result, "50 Nagpur cameras reseeded successfully"));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'SURVEY_PERSON', 'POLICE_OFFICER')")
    @Operation(summary = "Register new CCTV camera (Field Survey / Admin Entry)")
    public ResponseEntity<ApiResponse<CameraResponse>> createCamera(
            @Valid @RequestBody CameraCreateRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        CameraResponse response = cameraService.createCamera(request, userDetails.getUsername());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(response, "Camera registered successfully"));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get camera details by ID")
    public ResponseEntity<ApiResponse<CameraResponse>> getCameraById(@PathVariable Long id) {
        CameraResponse response = cameraService.getCameraById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/code/{cameraCode}")
    @Operation(summary = "Get camera details by unique Camera Code")
    public ResponseEntity<ApiResponse<CameraResponse>> getCameraByCode(@PathVariable String cameraCode) {
        CameraResponse response = cameraService.getCameraByCode(cameraCode);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping
    @Operation(summary = "Get paginated list of all cameras")
    public ResponseEntity<ApiResponse<Page<CameraResponse>>> getAllCameras(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "DESC") String sortDir) {
        Sort sort = sortDir.equalsIgnoreCase("ASC") ? Sort.by(sortBy).ascending() : Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);
        Page<CameraResponse> response = cameraService.getAllCameras(pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/search")
    @Operation(summary = "Filter cameras dynamically by location, area, status, or type")
    public ResponseEntity<ApiResponse<Page<CameraResponse>>> searchCameras(
            CameraSearchFilter filter,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        Pageable pageable = PageRequest.of(page, size);
        Page<CameraResponse> response = cameraService.searchCameras(filter, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/nearby")
    @Operation(summary = "PostGIS Geospatial Proximity Search: Find cameras within radius (in meters)")
    public ResponseEntity<ApiResponse<List<CameraResponse>>> getNearbyCameras(
            @RequestParam double latitude,
            @RequestParam double longitude,
            @RequestParam(defaultValue = "500") double radiusMeters) {
        List<CameraResponse> response = cameraService.getNearbyCameras(latitude, longitude, radiusMeters);
        return ResponseEntity.ok(ApiResponse.success(response, "Found " + response.size() + " cameras within radius"));
    }

    @GetMapping("/owner-lookup")
    @PreAuthorize("hasAnyRole('ADMIN', 'SURVEY_PERSON', 'POLICE_OFFICER')")
    @Operation(summary = "Surveyor Owner Verification: Lookup existing registered cameras and summary by owner mobile number")
    public ResponseEntity<ApiResponse<OwnerSummaryResponse>> lookupOwnerByContact(@RequestParam String contact) {
        OwnerSummaryResponse response = cameraService.lookupOwnerByContact(contact);
        String msg = response.isOwnerFound() 
                ? "Found " + response.getTotalCameras() + " cameras registered under owner: " + response.getOwnerName()
                : "No registered cameras found for contact: " + contact;
        return ResponseEntity.ok(ApiResponse.success(response, msg));
    }

    @GetMapping("/check-duplicate")
    @PreAuthorize("hasAnyRole('ADMIN', 'SURVEY_PERSON', 'POLICE_OFFICER')")
    @Operation(summary = "Surveyor Duplicate Check: Check if serial number or camera code is already registered")
    public ResponseEntity<ApiResponse<DuplicateCheckResponse>> checkDuplicate(
            @RequestParam(required = false) String serialNumber,
            @RequestParam(required = false) String cameraCode) {
        DuplicateCheckResponse response = cameraService.checkDuplicate(serialNumber, cameraCode);
        return ResponseEntity.ok(ApiResponse.success(response, response.getMessage()));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'SURVEY_PERSON')")
    @Operation(summary = "Update camera details")
    public ResponseEntity<ApiResponse<CameraResponse>> updateCamera(
            @PathVariable Long id,
            @Valid @RequestBody CameraCreateRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        CameraResponse response = cameraService.updateCamera(id, request, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(response, "Camera updated successfully"));
    }

    @PatchMapping("/{id}/approval")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Approve or reject surveyed camera (Admin verification queue)")
    public ResponseEntity<ApiResponse<CameraResponse>> approveOrRejectCamera(
            @PathVariable Long id,
            @Valid @RequestBody CameraApprovalRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        CameraResponse response = cameraService.approveOrRejectCamera(id, request, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(response, "Camera verification status updated to " + request.getVerificationStatus()));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Soft-delete camera")
    public ResponseEntity<ApiResponse<Void>> deleteCamera(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        cameraService.deleteCamera(id, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(null, "Camera deleted successfully"));
    }
}
