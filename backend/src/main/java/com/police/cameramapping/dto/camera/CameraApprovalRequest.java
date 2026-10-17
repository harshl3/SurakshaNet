package com.police.cameramapping.dto.camera;

import com.police.cameramapping.domain.model.enums.VerificationStatus;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class CameraApprovalRequest {
    @NotNull(message = "Verification status is required")
    private VerificationStatus verificationStatus;
    
    private String rejectionReason;
}
