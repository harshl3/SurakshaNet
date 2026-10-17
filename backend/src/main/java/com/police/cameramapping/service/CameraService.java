package com.police.cameramapping.service;

import com.police.cameramapping.dto.camera.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

import java.util.List;

public interface CameraService {
    CameraResponse createCamera(CameraCreateRequest request, String currentUsername);
    CameraResponse updateCamera(Long id, CameraCreateRequest request, String currentUsername);
    CameraResponse getCameraById(Long id);
    CameraResponse getCameraByCode(String cameraCode);
    Page<CameraResponse> getAllCameras(Pageable pageable);
    Page<CameraResponse> searchCameras(CameraSearchFilter filter, Pageable pageable);
    List<CameraResponse> getNearbyCameras(double latitude, double longitude, double radiusMeters);
    CameraResponse approveOrRejectCamera(Long id, CameraApprovalRequest request, String currentUsername);
    void deleteCamera(Long id, String currentUsername);
    OwnerSummaryResponse lookupOwnerByContact(String contact);
    DuplicateCheckResponse checkDuplicate(String serialNumber, String cameraCode);
}
