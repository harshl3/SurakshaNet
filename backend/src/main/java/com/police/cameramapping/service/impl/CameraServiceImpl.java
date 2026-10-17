package com.police.cameramapping.service.impl;

import com.police.cameramapping.common.exception.BadRequestException;
import com.police.cameramapping.common.exception.ResourceNotFoundException;
import com.police.cameramapping.domain.model.Camera;
import com.police.cameramapping.domain.model.PoliceStation;
import com.police.cameramapping.domain.model.User;
import com.police.cameramapping.domain.model.enums.CameraStatus;
import com.police.cameramapping.domain.model.enums.RoleEnum;
import com.police.cameramapping.domain.model.enums.VerificationStatus;
import com.police.cameramapping.domain.repository.CameraRepository;
import com.police.cameramapping.domain.repository.PoliceStationRepository;
import com.police.cameramapping.domain.repository.UserRepository;
import com.police.cameramapping.dto.camera.*;
import com.police.cameramapping.service.CameraService;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class CameraServiceImpl implements CameraService {

    private final CameraRepository cameraRepository;
    private final UserRepository userRepository;
    private final PoliceStationRepository policeStationRepository;
    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    @Override
    @Transactional
    public CameraResponse createCamera(CameraCreateRequest request, String currentUsername) {
        if (cameraRepository.existsByCameraCode(request.getCameraCode())) {
            throw new BadRequestException("Camera code '" + request.getCameraCode() + "' already exists!");
        }

        if (request.getSerialNumber() != null && !request.getSerialNumber().trim().isEmpty()) {
            if (cameraRepository.existsBySerialNumber(request.getSerialNumber().trim())) {
                throw new BadRequestException("Camera with Serial Number '" + request.getSerialNumber().trim() + "' already exists in the system!");
            }
        }

        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new ResourceNotFoundException("User", "username", currentUsername));

        PoliceStation station = null;
        if (request.getPoliceStationId() != null) {
            station = policeStationRepository.findById(request.getPoliceStationId())
                    .orElseThrow(() -> new ResourceNotFoundException("PoliceStation", "id", request.getPoliceStationId()));
        } else if (user.getPoliceStation() != null) {
            station = user.getPoliceStation();
        }

        // PostGIS geometry creation: Point(longitude, latitude)
        Point point = geometryFactory.createPoint(new Coordinate(request.getLongitude(), request.getLatitude()));

        VerificationStatus initialStatus = (user.getRole().getName() == RoleEnum.ROLE_ADMIN) 
                ? VerificationStatus.APPROVED 
                : VerificationStatus.PENDING;

        Camera camera = Camera.builder()
                .cameraCode(request.getCameraCode())
                .serialNumber(request.getSerialNumber())
                .cameraName(request.getCameraName())
                .cameraType(request.getCameraType())
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .locationGeom(point)
                .fullAddress(request.getFullAddress())
                .area(request.getArea())
                .ward(request.getWard())
                .zone(request.getZone())
                .city(request.getCity())
                .state(request.getState())
                .cardinalDirection(request.getCardinalDirection())
                .directionAngle(request.getDirectionAngle() != null ? request.getDirectionAngle() : 0.0)
                .fovAngle(request.getFovAngle() != null ? request.getFovAngle() : 60.0)
                .coverageRadiusMeters(request.getCoverageRadiusMeters() != null ? request.getCoverageRadiusMeters() : 100.0)
                .installationDate(request.getInstallationDate() != null ? request.getInstallationDate() : LocalDate.now())
                .surveyDate(LocalDate.now())
                .cameraStatus(CameraStatus.ACTIVE)
                .verificationStatus(initialStatus)
                .imageUrl(request.getImageUrl())
                .qrCodeUrl("https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=" + request.getCameraCode())
                .ownerName(request.getOwnerName())
                .ownerContact(request.getOwnerContact())
                .ownerType(request.getOwnerType() != null ? request.getOwnerType() : "COMMERCIAL")
                .surveyor(user)
                .policeStation(station)
                .build();

        camera.setCreatedBy(currentUsername);
        Camera saved = cameraRepository.save(camera);

        return mapToResponse(saved);
    }

    @Override
    @Transactional
    public CameraResponse updateCamera(Long id, CameraCreateRequest request, String currentUsername) {
        Camera camera = cameraRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Camera", "id", id));

        Point point = geometryFactory.createPoint(new Coordinate(request.getLongitude(), request.getLatitude()));

        camera.setCameraName(request.getCameraName());
        if (request.getSerialNumber() != null) camera.setSerialNumber(request.getSerialNumber());
        camera.setCameraType(request.getCameraType());
        camera.setLatitude(request.getLatitude());
        camera.setLongitude(request.getLongitude());
        camera.setLocationGeom(point);
        camera.setFullAddress(request.getFullAddress());
        camera.setArea(request.getArea());
        camera.setWard(request.getWard());
        camera.setZone(request.getZone());
        if (request.getDirectionAngle() != null) camera.setDirectionAngle(request.getDirectionAngle());
        if (request.getFovAngle() != null) camera.setFovAngle(request.getFovAngle());
        if (request.getCoverageRadiusMeters() != null) camera.setCoverageRadiusMeters(request.getCoverageRadiusMeters());
        if (request.getImageUrl() != null) camera.setImageUrl(request.getImageUrl());
        
        camera.setUpdatedBy(currentUsername);

        return mapToResponse(cameraRepository.save(camera));
    }

    @Override
    @Transactional(readOnly = true)
    public OwnerSummaryResponse lookupOwnerByContact(String contact) {
        if (contact == null || contact.trim().isEmpty()) {
            return OwnerSummaryResponse.builder()
                    .ownerFound(false)
                    .cameras(List.of())
                    .build();
        }

        String raw = contact.trim();
        String digitsOnly = raw.replaceAll("[^0-9]", "");
        String searchDigits = digitsOnly.length() >= 10 ? digitsOnly.substring(digitsOnly.length() - 10) : digitsOnly;

        List<Camera> matchedCameras = List.of();
        if (!searchDigits.isEmpty()) {
            matchedCameras = cameraRepository.searchByCleanContact(searchDigits);
        }
        if (matchedCameras.isEmpty()) {
            matchedCameras = cameraRepository.findByOwnerContactAndIsDeletedFalse(raw);
        }

        if (matchedCameras.isEmpty()) {
            return OwnerSummaryResponse.builder()
                    .ownerFound(false)
                    .ownerContact(raw)
                    .maskedContact(maskPhoneNumber(raw))
                    .totalCameras(0)
                    .approvedCount(0)
                    .pendingCount(0)
                    .rejectedCount(0)
                    .cameras(List.of())
                    .build();
        }

        Camera primary = matchedCameras.get(0);
        long approved = matchedCameras.stream().filter(c -> c.getVerificationStatus() == VerificationStatus.APPROVED).count();
        long pending = matchedCameras.stream().filter(c -> c.getVerificationStatus() == VerificationStatus.PENDING).count();
        long rejected = matchedCameras.stream().filter(c -> c.getVerificationStatus() == VerificationStatus.REJECTED).count();

        List<CameraResponse> cameraResponses = matchedCameras.stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());

        return OwnerSummaryResponse.builder()
                .ownerFound(true)
                .ownerName(primary.getOwnerName())
                .ownerContact(primary.getOwnerContact())
                .maskedContact(maskPhoneNumber(primary.getOwnerContact()))
                .ownerType(primary.getOwnerType())
                .totalCameras(matchedCameras.size())
                .approvedCount(approved)
                .pendingCount(pending)
                .rejectedCount(rejected)
                .cameras(cameraResponses)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public DuplicateCheckResponse checkDuplicate(String serialNumber, String cameraCode) {
        if (serialNumber != null && !serialNumber.trim().isEmpty()) {
            var camOpt = cameraRepository.findBySerialNumber(serialNumber.trim());
            if (camOpt.isPresent()) {
                Camera cam = camOpt.get();
                return DuplicateCheckResponse.builder()
                        .duplicate(true)
                        .duplicateField("serialNumber")
                        .message("Camera with Serial Number '" + serialNumber.trim() + "' is already registered under " + (cam.getOwnerName() != null ? cam.getOwnerName() : "existing location") + " (" + cam.getCameraCode() + ").")
                        .existingCamera(mapToResponse(cam))
                        .build();
            }
        }

        if (cameraCode != null && !cameraCode.trim().isEmpty()) {
            var camOpt = cameraRepository.findByCameraCode(cameraCode.trim());
            if (camOpt.isPresent()) {
                Camera cam = camOpt.get();
                return DuplicateCheckResponse.builder()
                        .duplicate(true)
                        .duplicateField("cameraCode")
                        .message("Camera Code '" + cameraCode.trim() + "' already exists in the system (" + cam.getCameraName() + ").")
                        .existingCamera(mapToResponse(cam))
                        .build();
            }
        }

        return DuplicateCheckResponse.builder()
                .duplicate(false)
                .message("No duplicate found. Serial Number and Camera Code are available.")
                .build();
    }

    private String maskPhoneNumber(String phone) {
        if (phone == null || phone.length() < 4) return "XXXX";
        String digits = phone.replaceAll("[^0-9]", "");
        if (digits.length() <= 3) return "XXXX";
        String lastThree = digits.substring(digits.length() - 3);
        return "XXXXXXX" + lastThree;
    }

    @Override
    @Transactional(readOnly = true)
    public CameraResponse getCameraById(Long id) {
        Camera camera = cameraRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Camera", "id", id));
        return mapToResponse(camera);
    }

    @Override
    @Transactional(readOnly = true)
    public CameraResponse getCameraByCode(String cameraCode) {
        Camera camera = cameraRepository.findByCameraCode(cameraCode)
                .orElseThrow(() -> new ResourceNotFoundException("Camera", "cameraCode", cameraCode));
        return mapToResponse(camera);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<CameraResponse> getAllCameras(Pageable pageable) {
        return cameraRepository.findAll(pageable).map(this::mapToResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public Page<CameraResponse> searchCameras(CameraSearchFilter filter, Pageable pageable) {
        Specification<Camera> spec = (root, query, cb) -> {
            var predicates = cb.conjunction();
            predicates = cb.and(predicates, cb.equal(root.get("isDeleted"), false));

            if (filter.getQuery() != null && !filter.getQuery().trim().isEmpty()) {
                String term = "%" + filter.getQuery().trim().toLowerCase() + "%";
                predicates = cb.and(predicates, cb.or(
                        cb.like(cb.lower(root.get("cameraCode")), term),
                        cb.like(cb.lower(root.get("cameraName")), term),
                        cb.like(cb.lower(root.get("fullAddress")), term),
                        cb.like(cb.lower(root.get("area")), term),
                        cb.like(cb.lower(root.get("zone")), term),
                        cb.like(cb.lower(root.get("ward")), term),
                        cb.like(cb.lower(root.get("ownerName")), term),
                        cb.like(cb.lower(root.get("ownerContact")), term),
                        cb.like(cb.lower(root.get("policeStation").get("stationName")), term)
                ));
            }

            if (filter.getArea() != null && !filter.getArea().isEmpty()) {
                predicates = cb.and(predicates, cb.equal(root.get("area"), filter.getArea()));
            }

            if (filter.getPoliceStationId() != null) {
                predicates = cb.and(predicates, cb.equal(root.get("policeStation").get("id"), filter.getPoliceStationId()));
            }

            if (filter.getCameraType() != null) {
                predicates = cb.and(predicates, cb.equal(root.get("cameraType"), filter.getCameraType()));
            }

            if (filter.getCameraStatus() != null) {
                predicates = cb.and(predicates, cb.equal(root.get("cameraStatus"), filter.getCameraStatus()));
            }

            if (filter.getVerificationStatus() != null) {
                predicates = cb.and(predicates, cb.equal(root.get("verificationStatus"), filter.getVerificationStatus()));
            }

            return predicates;
        };

        return cameraRepository.findAll(spec, pageable).map(this::mapToResponse);
    }

    @Override
    @Transactional(readOnly = true)
    public List<CameraResponse> getNearbyCameras(double latitude, double longitude, double radiusMeters) {
        List<Camera> cameras = cameraRepository.findNearbyCameras(latitude, longitude, radiusMeters);
        return cameras.stream()
                .map(cam -> {
                    CameraResponse resp = mapToResponse(cam);
                    // Compute distance in meters using Haversine formula
                    double dist = calculateHaversineDistance(latitude, longitude, cam.getLatitude(), cam.getLongitude());
                    resp.setDistanceMeters(Math.round(dist * 10.0) / 10.0);
                    return resp;
                })
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public CameraResponse approveOrRejectCamera(Long id, CameraApprovalRequest request, String currentUsername) {
        Camera camera = cameraRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Camera", "id", id));

        camera.setVerificationStatus(request.getVerificationStatus());
        if (request.getVerificationStatus() == VerificationStatus.REJECTED) {
            camera.setRejectionReason(request.getRejectionReason());
        }
        camera.setUpdatedBy(currentUsername);

        return mapToResponse(cameraRepository.save(camera));
    }

    @Override
    @Transactional
    public void deleteCamera(Long id, String currentUsername) {
        Camera camera = cameraRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Camera", "id", id));
        camera.setDeleted(true);
        camera.setUpdatedBy(currentUsername);
        cameraRepository.save(camera);
    }

    private CameraResponse mapToResponse(Camera camera) {
        String ownerName = camera.getOwnerName();
        String ownerContact = camera.getOwnerContact();
        String ownerType = camera.getOwnerType();

        return CameraResponse.builder()
                .id(camera.getId())
                .cameraCode(camera.getCameraCode())
                .serialNumber(camera.getSerialNumber())
                .cameraName(camera.getCameraName())
                .cameraType(camera.getCameraType())
                .latitude(camera.getLatitude())
                .longitude(camera.getLongitude())
                .fullAddress(camera.getFullAddress())
                .area(camera.getArea())
                .ward(camera.getWard())
                .zone(camera.getZone())
                .city(camera.getCity())
                .state(camera.getState())
                .cardinalDirection(camera.getCardinalDirection())
                .directionAngle(camera.getDirectionAngle())
                .fovAngle(camera.getFovAngle() != null ? camera.getFovAngle() : 60.0)
                .coverageRadiusMeters(camera.getCoverageRadiusMeters())
                .installationDate(camera.getInstallationDate())
                .surveyDate(camera.getSurveyDate())
                .cameraStatus(camera.getCameraStatus())
                .verificationStatus(camera.getVerificationStatus())
                .rejectionReason(camera.getRejectionReason())
                .imageUrl(camera.getImageUrl())
                .qrCodeUrl(camera.getQrCodeUrl())
                .ownerName(ownerName)
                .ownerContact(ownerContact)
                .ownerType(ownerType)
                .surveyorId(camera.getSurveyor() != null ? camera.getSurveyor().getId() : null)
                .surveyorName(camera.getSurveyor() != null ? camera.getSurveyor().getFullName() : null)
                .policeStationId(camera.getPoliceStation() != null ? camera.getPoliceStation().getId() : null)
                .policeStationName(camera.getPoliceStation() != null ? camera.getPoliceStation().getStationName() : null)
                .createdAt(camera.getCreatedAt())
                .updatedAt(camera.getUpdatedAt())
                .build();
    }

    private double calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
        final int EARTH_RADIUS = 6371000; // Meters
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                        Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS * c;
    }
}
