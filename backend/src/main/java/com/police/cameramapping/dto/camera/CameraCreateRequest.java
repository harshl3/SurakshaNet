package com.police.cameramapping.dto.camera;

import com.police.cameramapping.domain.model.enums.CameraType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

@Data
public class CameraCreateRequest {
    @NotBlank(message = "Camera code is required")
    private String cameraCode;

    @NotBlank(message = "Camera name is required")
    private String cameraName;

    private String serialNumber;

    @NotNull(message = "Camera type is required")
    private CameraType cameraType;

    @NotNull(message = "Latitude is required")
    private Double latitude;

    @NotNull(message = "Longitude is required")
    private Double longitude;

    private String fullAddress;
    private String area;
    private String ward;
    private String zone;
    private String city;
    private String state;
    private String cardinalDirection;
    
    private Double directionAngle = 0.0;
    private Double fovAngle = 60.0; // Field of view capture angle width
    private Double coverageRadiusMeters = 100.0;
    
    private LocalDate installationDate;
    private Long policeStationId;
    private String imageUrl;

    private String ownerName;
    private String ownerContact;
    private String ownerType;
}
