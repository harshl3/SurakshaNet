package com.police.cameramapping.dto.camera;

import com.police.cameramapping.domain.model.enums.CameraStatus;
import com.police.cameramapping.domain.model.enums.CameraType;
import com.police.cameramapping.domain.model.enums.VerificationStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CameraResponse {
    private Long id;
    private String cameraCode;
    private String serialNumber;
    private String cameraName;
    private CameraType cameraType;
    private Double latitude;
    private Double longitude;
    private String fullAddress;
    private String area;
    private String ward;
    private String zone;
    private String city;
    private String state;
    private String cardinalDirection;
    private Double directionAngle;
    private Double fovAngle;
    private Double coverageRadiusMeters;
    private LocalDate installationDate;
    private LocalDate surveyDate;
    private CameraStatus cameraStatus;
    private VerificationStatus verificationStatus;
    private String rejectionReason;
    private String imageUrl;
    private String qrCodeUrl;
    
    private String ownerName;
    private String ownerContact;
    private String ownerType;
    
    private Long surveyorId;
    private String surveyorName;
    
    private Long policeStationId;
    private String policeStationName;
    
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    
    // Optional field when executing proximity queries
    private Double distanceMeters;
}
