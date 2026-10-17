package com.police.cameramapping.dto.camera;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OwnerSummaryResponse {
    private boolean ownerFound;
    private String ownerName;
    private String ownerContact;
    private String maskedContact;
    private String ownerType;
    private int totalCameras;
    private long approvedCount;
    private long pendingCount;
    private long rejectedCount;
    private List<CameraResponse> cameras;
}
