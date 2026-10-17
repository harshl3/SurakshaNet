package com.police.cameramapping.service.impl;

import com.police.cameramapping.common.exception.BadRequestException;
import com.police.cameramapping.common.exception.ResourceNotFoundException;
import com.police.cameramapping.domain.model.*;
import com.police.cameramapping.domain.model.enums.CaseStatus;
import com.police.cameramapping.domain.repository.*;
import com.police.cameramapping.dto.camera.CameraResponse;
import com.police.cameramapping.dto.investigation.CaseCameraAttachRequest;
import com.police.cameramapping.dto.investigation.InvestigationCaseRequest;
import com.police.cameramapping.dto.investigation.InvestigationCaseResponse;
import com.police.cameramapping.service.CameraService;
import com.police.cameramapping.service.InvestigationService;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class InvestigationServiceImpl implements InvestigationService {

    private final InvestigationCaseRepository investigationCaseRepository;
    private final CaseCameraRepository caseCameraRepository;
    private final CameraRepository cameraRepository;
    private final UserRepository userRepository;
    private final PoliceStationRepository policeStationRepository;
    private final CameraService cameraService;
    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    @Override
    @Transactional
    public InvestigationCaseResponse createCase(InvestigationCaseRequest request, String currentUsername) {
        if (investigationCaseRepository.existsByCaseNumber(request.getCaseNumber())) {
            throw new BadRequestException("Case number '" + request.getCaseNumber() + "' already exists!");
        }

        User officer = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new ResourceNotFoundException("User", "username", currentUsername));

        PoliceStation station = null;
        if (request.getPoliceStationId() != null) {
            station = policeStationRepository.findById(request.getPoliceStationId())
                    .orElseThrow(() -> new ResourceNotFoundException("PoliceStation", "id", request.getPoliceStationId()));
        } else if (officer.getPoliceStation() != null) {
            station = officer.getPoliceStation();
        }

        Point crimePoint = geometryFactory.createPoint(new Coordinate(request.getLongitude(), request.getLatitude()));

        InvestigationCase caseEntity = InvestigationCase.builder()
                .caseNumber(request.getCaseNumber())
                .firNumber(request.getFirNumber())
                .title(request.getTitle())
                .crimeType(request.getCrimeType())
                .crimeLocationName(request.getCrimeLocationName())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .crimeLocationGeom(crimePoint)
                .incidentDate(request.getIncidentDate() != null ? request.getIncidentDate() : java.time.LocalDateTime.now())
                .description(request.getDescription())
                .status(CaseStatus.OPEN)
                .assignedOfficer(officer)
                .policeStation(station)
                .build();

        caseEntity.setCreatedBy(currentUsername);
        InvestigationCase savedCase = investigationCaseRepository.save(caseEntity);

        // Auto-discover nearby cameras using PostGIS — use Camera entities directly (no N+1)
        double radius = (request.getSearchRadiusMeters() != null) ? request.getSearchRadiusMeters() : 500.0;
        List<Camera> nearbyCameras = cameraRepository.findNearbyCameras(request.getLatitude(), request.getLongitude(), radius);

        List<CameraResponse> attachedCameraResponses = nearbyCameras.stream().map(camera -> {
            CaseCamera caseCamera = CaseCamera.builder()
                    .investigationCase(savedCase)
                    .camera(camera)
                    .distanceMeters(null)
                    .evidenceNotes("Auto-attached based on crime location proximity")
                    .build();
            caseCamera.setCreatedBy(currentUsername);
            caseCameraRepository.save(caseCamera);
            return CameraResponse.builder()
                    .id(camera.getId())
                    .cameraCode(camera.getCameraCode())
                    .cameraName(camera.getCameraName())
                    .cameraType(camera.getCameraType())
                    .latitude(camera.getLatitude())
                    .longitude(camera.getLongitude())
                    .fullAddress(camera.getFullAddress())
                    .area(camera.getArea())
                    .cameraStatus(camera.getCameraStatus())
                    .verificationStatus(camera.getVerificationStatus())
                    .imageUrl(camera.getImageUrl())
                    .build();
        }).collect(Collectors.toList());

        // Build response directly from saved entities — no extra DB round-trip
        return InvestigationCaseResponse.builder()
                .id(savedCase.getId())
                .caseNumber(savedCase.getCaseNumber())
                .firNumber(savedCase.getFirNumber())
                .title(savedCase.getTitle())
                .crimeType(savedCase.getCrimeType())
                .crimeLocationName(savedCase.getCrimeLocationName())
                .latitude(savedCase.getLatitude())
                .longitude(savedCase.getLongitude())
                .incidentDate(savedCase.getIncidentDate())
                .description(savedCase.getDescription())
                .status(savedCase.getStatus())
                .assignedOfficerId(officer.getId())
                .assignedOfficerName(officer.getFullName())
                .assignedOfficerBadge(officer.getBadgeNumber())
                .policeStationId(station != null ? station.getId() : null)
                .policeStationName(station != null ? station.getStationName() : null)
                .attachedCameras(attachedCameraResponses)
                .createdAt(savedCase.getCreatedAt())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public InvestigationCaseResponse getCaseById(Long id) {
        InvestigationCase caseEntity = investigationCaseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("InvestigationCase", "id", id));

        List<CaseCamera> caseCameras = caseCameraRepository.findByInvestigationCase_IdAndIsDeletedFalse(id);
        List<CameraResponse> attachedCameras = caseCameras.stream()
                .map(cc -> {
                    Camera cam = cc.getCamera();
                    return CameraResponse.builder()
                            .id(cam.getId())
                            .cameraCode(cam.getCameraCode())
                            .cameraName(cam.getCameraName())
                            .cameraType(cam.getCameraType())
                            .latitude(cam.getLatitude())
                            .longitude(cam.getLongitude())
                            .fullAddress(cam.getFullAddress())
                            .area(cam.getArea())
                            .cameraStatus(cam.getCameraStatus())
                            .verificationStatus(cam.getVerificationStatus())
                            .distanceMeters(cc.getDistanceMeters())
                            .imageUrl(cam.getImageUrl())
                            .build();
                })
                .collect(Collectors.toList());

        return InvestigationCaseResponse.builder()
                .id(caseEntity.getId())
                .caseNumber(caseEntity.getCaseNumber())
                .firNumber(caseEntity.getFirNumber())
                .title(caseEntity.getTitle())
                .crimeType(caseEntity.getCrimeType())
                .crimeLocationName(caseEntity.getCrimeLocationName())
                .latitude(caseEntity.getLatitude())
                .longitude(caseEntity.getLongitude())
                .incidentDate(caseEntity.getIncidentDate())
                .description(caseEntity.getDescription())
                .status(caseEntity.getStatus())
                .assignedOfficerId(caseEntity.getAssignedOfficer() != null ? caseEntity.getAssignedOfficer().getId() : null)
                .assignedOfficerName(caseEntity.getAssignedOfficer() != null ? caseEntity.getAssignedOfficer().getFullName() : null)
                .assignedOfficerBadge(caseEntity.getAssignedOfficer() != null ? caseEntity.getAssignedOfficer().getBadgeNumber() : null)
                .policeStationId(caseEntity.getPoliceStation() != null ? caseEntity.getPoliceStation().getId() : null)
                .policeStationName(caseEntity.getPoliceStation() != null ? caseEntity.getPoliceStation().getStationName() : null)
                .attachedCameras(attachedCameras)
                .createdAt(caseEntity.getCreatedAt())
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public InvestigationCaseResponse getCaseByNumber(String caseNumber) {
        InvestigationCase caseEntity = investigationCaseRepository.findByCaseNumber(caseNumber)
                .orElseThrow(() -> new ResourceNotFoundException("InvestigationCase", "caseNumber", caseNumber));
        return getCaseById(caseEntity.getId());
    }

    @Override
    @Transactional(readOnly = true)
    public Page<InvestigationCase> getAllCases(Pageable pageable) {
        return investigationCaseRepository.findByIsDeletedFalse(pageable);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<InvestigationCaseResponse> getAllCaseResponses(Pageable pageable) {
        Page<InvestigationCase> cases;
        try {
            org.springframework.security.core.Authentication auth = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
            if (auth != null) {
                String username = auth.getName();
                User user = userRepository.findByUsername(username).orElse(null);
                if (user != null && user.getRole() != null && user.getRole().getName() == com.police.cameramapping.domain.model.enums.RoleEnum.ROLE_POLICE_OFFICER) {
                    cases = investigationCaseRepository.findByAssignedOfficer_IdAndIsDeletedFalse(user.getId(), pageable);
                    return cases.map(this::buildLightResponse);
                }
            }
        } catch (Exception ignored) {}

        return investigationCaseRepository.findByIsDeletedFalse(pageable).map(this::buildLightResponse);
    }

    /** Lightweight response builder that avoids extra DB queries per case. */
    private InvestigationCaseResponse buildLightResponse(InvestigationCase c) {
        return InvestigationCaseResponse.builder()
                .id(c.getId())
                .caseNumber(c.getCaseNumber())
                .firNumber(c.getFirNumber())
                .title(c.getTitle())
                .crimeType(c.getCrimeType())
                .crimeLocationName(c.getCrimeLocationName())
                .latitude(c.getLatitude())
                .longitude(c.getLongitude())
                .incidentDate(c.getIncidentDate())
                .description(c.getDescription())
                .status(c.getStatus())
                .assignedOfficerId(c.getAssignedOfficer() != null ? c.getAssignedOfficer().getId() : null)
                .assignedOfficerName(c.getAssignedOfficer() != null ? c.getAssignedOfficer().getFullName() : null)
                .assignedOfficerBadge(c.getAssignedOfficer() != null ? c.getAssignedOfficer().getBadgeNumber() : null)
                .policeStationId(c.getPoliceStation() != null ? c.getPoliceStation().getId() : null)
                .policeStationName(c.getPoliceStation() != null ? c.getPoliceStation().getStationName() : null)
                .attachedCameras(List.of())
                .createdAt(c.getCreatedAt())
                .build();
    }

    @Override
    @Transactional
    public InvestigationCaseResponse attachCameraToCase(Long caseId, CaseCameraAttachRequest request, String currentUsername) {
        InvestigationCase caseEntity = investigationCaseRepository.findById(caseId)
                .orElseThrow(() -> new ResourceNotFoundException("InvestigationCase", "id", caseId));

        Camera camera = cameraRepository.findById(request.getCameraId())
                .orElseThrow(() -> new ResourceNotFoundException("Camera", "id", request.getCameraId()));

        if (caseCameraRepository.existsByInvestigationCase_IdAndCamera_Id(caseId, request.getCameraId())) {
            throw new BadRequestException("Camera is already attached to this investigation case");
        }

        CaseCamera caseCamera = CaseCamera.builder()
                .investigationCase(caseEntity)
                .camera(camera)
                .footageStartTime(request.getFootageStartTime())
                .footageEndTime(request.getFootageEndTime())
                .evidenceNotes(request.getEvidenceNotes())
                .isKeyEvidence(request.isKeyEvidence())
                .build();

        caseCamera.setCreatedBy(currentUsername);
        caseCameraRepository.save(caseCamera);

        return getCaseById(caseId);
    }

    @Override
    @Transactional
    public void deleteCase(Long id, String currentUsername) {
        InvestigationCase caseEntity = investigationCaseRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("InvestigationCase", "id", id));
        caseEntity.setDeleted(true);
        caseEntity.setUpdatedBy(currentUsername);
        investigationCaseRepository.save(caseEntity);
    }
}
