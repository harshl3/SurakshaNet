package com.police.cameramapping.dto.investigation;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDateTime;

@Data
public class CaseCameraAttachRequest {
    @NotNull(message = "Camera ID is required")
    private Long cameraId;

    private LocalDateTime footageStartTime;
    private LocalDateTime footageEndTime;
    private String evidenceNotes;
    private boolean isKeyEvidence = false;
}
