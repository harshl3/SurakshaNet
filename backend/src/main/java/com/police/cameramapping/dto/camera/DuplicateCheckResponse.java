package com.police.cameramapping.dto.camera;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DuplicateCheckResponse {
    private boolean duplicate;
    private String duplicateField; // "serialNumber" or "cameraCode"
    private String message;
    private CameraResponse existingCamera;
}
