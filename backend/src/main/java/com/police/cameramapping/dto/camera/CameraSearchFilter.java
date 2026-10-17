package com.police.cameramapping.dto.camera;

import com.police.cameramapping.domain.model.enums.CameraStatus;
import com.police.cameramapping.domain.model.enums.CameraType;
import com.police.cameramapping.domain.model.enums.VerificationStatus;
import lombok.Data;

@Data
public class CameraSearchFilter {
    private String query;
    private String area;
    private String zone;
    private Long policeStationId;
    private CameraType cameraType;
    private CameraStatus cameraStatus;
    private VerificationStatus verificationStatus;
    
    // Proximity parameters
    private Double latitude;
    private Double longitude;
    private Double radiusMeters;
}
