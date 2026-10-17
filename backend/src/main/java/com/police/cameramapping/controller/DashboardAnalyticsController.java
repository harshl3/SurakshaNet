package com.police.cameramapping.controller;

import com.police.cameramapping.common.dto.ApiResponse;
import com.police.cameramapping.domain.model.enums.CameraStatus;
import com.police.cameramapping.domain.model.enums.CaseStatus;
import com.police.cameramapping.domain.model.enums.VerificationStatus;
import com.police.cameramapping.domain.repository.*;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/dashboard")
@RequiredArgsConstructor
@Tag(name = "Dashboard & Analytics Module", description = "Realtime aggregate statistics and role dashboard counters")
public class DashboardAnalyticsController {

    private final CameraRepository cameraRepository;
    private final UserRepository userRepository;
    private final PoliceStationRepository policeStationRepository;
    private final InvestigationCaseRepository investigationCaseRepository;

    @Data
    @Builder
    public static class AnalyticsResponse {
        private long totalCameras;
        private long activeCameras;
        private long offlineCameras;
        private long pendingVerificationCameras;
        private long verifiedCameras;
        private long totalPoliceStations;
        private long totalUsers;
        private long totalInvestigationCases;
        private long openCases;
    }

    @GetMapping("/stats")
    @Operation(summary = "Get overall dashboard KPI statistics")
    public ResponseEntity<ApiResponse<AnalyticsResponse>> getDashboardStats() {
        AnalyticsResponse stats = AnalyticsResponse.builder()
                .totalCameras(cameraRepository.count())
                .activeCameras(cameraRepository.countByCameraStatusAndIsDeletedFalse(CameraStatus.ACTIVE))
                .offlineCameras(cameraRepository.countByCameraStatusAndIsDeletedFalse(CameraStatus.OFFLINE))
                .pendingVerificationCameras(cameraRepository.countByVerificationStatusAndIsDeletedFalse(VerificationStatus.PENDING))
                .verifiedCameras(cameraRepository.countByVerificationStatusAndIsDeletedFalse(VerificationStatus.APPROVED))
                .totalPoliceStations(policeStationRepository.count())
                .totalUsers(userRepository.count())
                .totalInvestigationCases(investigationCaseRepository.count())
                .openCases(investigationCaseRepository.countByStatusAndIsDeletedFalse(CaseStatus.OPEN))
                .build();

        return ResponseEntity.ok(ApiResponse.success(stats, "Dashboard statistics fetched successfully"));
    }
}
