package com.police.cameramapping.dto.investigation;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class InvestigationCaseRequest {
    @NotBlank(message = "Case number is required")
    private String caseNumber;

    private String firNumber;

    @NotBlank(message = "Title is required")
    private String title;

    @NotBlank(message = "Crime type is required")
    private String crimeType;

    private String crimeLocationName;

    @NotNull(message = "Latitude is required")
    private Double latitude;

    @NotNull(message = "Longitude is required")
    private Double longitude;

    private LocalDateTime incidentDate;

    private String description;
    private Long policeStationId;
    
    // Auto-search radius for recommended cameras
    private Double searchRadiusMeters = 500.0;
}
