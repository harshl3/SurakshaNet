package com.police.cameramapping.dto.investigation;

import com.police.cameramapping.domain.model.enums.CaseStatus;
import com.police.cameramapping.dto.camera.CameraResponse;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class InvestigationCaseResponse {
    private Long id;
    private String caseNumber;
    private String firNumber;
    private String title;
    private String crimeType;
    private String crimeLocationName;
    private Double latitude;
    private Double longitude;
    private LocalDateTime incidentDate;
    private String description;
    private CaseStatus status;
    
    private Long assignedOfficerId;
    private String assignedOfficerName;
    private String assignedOfficerBadge;
    
    private Long policeStationId;
    private String policeStationName;
    
    private List<CameraResponse> attachedCameras;
    private LocalDateTime createdAt;
}
