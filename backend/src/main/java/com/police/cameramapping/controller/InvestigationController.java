package com.police.cameramapping.controller;

import com.police.cameramapping.common.dto.ApiResponse;
import com.police.cameramapping.dto.investigation.CaseCameraAttachRequest;
import com.police.cameramapping.dto.investigation.InvestigationCaseRequest;
import com.police.cameramapping.dto.investigation.InvestigationCaseResponse;
import com.police.cameramapping.domain.model.InvestigationCase;
import com.police.cameramapping.service.InvestigationService;
import com.police.cameramapping.service.NagpurInvestigationSeederService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/investigations")
@RequiredArgsConstructor
@Tag(name = "Investigation Case & Evidence Linkage Module", description = "Endpoints for police investigation cases, automated camera radius matching, and evidence tracking")
public class InvestigationController {

    private final InvestigationService investigationService;
    private final NagpurInvestigationSeederService nagpurInvestigationSeederService;

    @PostMapping("/seed-nagpur")
    @Operation(summary = "Purge and reseed 8 realistic Nagpur police investigations with PostGIS linked CCTV nodes")
    public ResponseEntity<ApiResponse<Map<String, Object>>> seedNagpurInvestigations() {
        List<InvestigationCase> seeded = nagpurInvestigationSeederService.reseedNagpurInvestigations();
        Map<String, Object> result = Map.of(
                "message", "Successfully purged previous records and seeded " + seeded.size() + " realistic Nagpur investigation cases.",
                "totalCases", seeded.size(),
                "cases", seeded.stream().map(c -> Map.of(
                        "id", c.getId(),
                        "caseNumber", c.getCaseNumber(),
                        "firNumber", c.getFirNumber() != null ? c.getFirNumber() : "",
                        "title", c.getTitle(),
                        "crimeType", c.getCrimeType(),
                        "location", c.getCrimeLocationName() != null ? c.getCrimeLocationName() : "",
                        "coords", c.getLatitude() + ", " + c.getLongitude(),
                        "status", c.getStatus().name()
                )).toList()
        );
        return ResponseEntity.ok(ApiResponse.success(result, "Nagpur investigation cases seeded successfully"));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'POLICE_OFFICER', 'SURVEY_PERSON')")
    @Operation(summary = "Create new investigation case with automatic PostGIS camera radius discovery")
    public ResponseEntity<ApiResponse<InvestigationCaseResponse>> createCase(
            @Valid @RequestBody InvestigationCaseRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        InvestigationCaseResponse response = investigationService.createCase(request, userDetails.getUsername());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(response, "Investigation case created and nearby cameras linked"));
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'POLICE_OFFICER')")
    @Operation(summary = "Get history of all police officer investigation cases across all stations")
    public ResponseEntity<ApiResponse<org.springframework.data.domain.Page<InvestigationCaseResponse>>> getAllCases(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        org.springframework.data.domain.Page<InvestigationCaseResponse> cases = investigationService.getAllCaseResponses(
                org.springframework.data.domain.PageRequest.of(page, size, org.springframework.data.domain.Sort.by("createdAt").descending())
        );
        return ResponseEntity.ok(ApiResponse.success(cases, "Retrieved investigation history"));
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get investigation case details and linked cameras")
    public ResponseEntity<ApiResponse<InvestigationCaseResponse>> getCaseById(@PathVariable Long id) {
        InvestigationCaseResponse response = investigationService.getCaseById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping("/number/{caseNumber}")
    @Operation(summary = "Get investigation case details by unique Case Number")
    public ResponseEntity<ApiResponse<InvestigationCaseResponse>> getCaseByNumber(@PathVariable String caseNumber) {
        InvestigationCaseResponse response = investigationService.getCaseByNumber(caseNumber);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/{id}/cameras")
    @PreAuthorize("hasAnyRole('ADMIN', 'POLICE_OFFICER')")
    @Operation(summary = "Attach camera to investigation case with timeframe notes")
    public ResponseEntity<ApiResponse<InvestigationCaseResponse>> attachCameraToCase(
            @PathVariable Long id,
            @Valid @RequestBody CaseCameraAttachRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        InvestigationCaseResponse response = investigationService.attachCameraToCase(id, request, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(response, "Camera evidence attached to case"));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN', 'POLICE_OFFICER')")
    @Operation(summary = "Remove or close an investigation case")
    public ResponseEntity<ApiResponse<Void>> deleteCase(
            @PathVariable Long id,
            @AuthenticationPrincipal UserDetails userDetails) {
        investigationService.deleteCase(id, userDetails.getUsername());
        return ResponseEntity.ok(ApiResponse.success(null, "Investigation case removed successfully"));
    }
}
