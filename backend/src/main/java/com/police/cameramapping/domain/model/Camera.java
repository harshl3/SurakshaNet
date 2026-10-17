package com.police.cameramapping.domain.model;

import com.police.cameramapping.domain.model.enums.CameraStatus;
import com.police.cameramapping.domain.model.enums.CameraType;
import com.police.cameramapping.domain.model.enums.VerificationStatus;
import jakarta.persistence.*;
import lombok.*;
import org.locationtech.jts.geom.Point;

import java.time.LocalDate;

@Entity
@Table(name = "cameras")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Camera extends BaseEntity {

    @Column(name = "camera_code", nullable = false, unique = true, length = 50)
    private String cameraCode;

    @Column(name = "camera_name", nullable = false, length = 150)
    private String cameraName;

    @Enumerated(EnumType.STRING)
    @Column(name = "camera_type", nullable = false, length = 30)
    private CameraType cameraType;

    @Column(nullable = false)
    private Double latitude;

    @Column(nullable = false)
    private Double longitude;

    @Column(name = "location_geom", columnDefinition = "geometry(Point,4326)", nullable = false)
    private Point locationGeom;

    @Column(name = "full_address", columnDefinition = "TEXT")
    private String fullAddress;

    @Column(length = 100)
    private String area;

    @Column(length = 50)
    private String ward;

    @Column(length = 50)
    private String zone;

    @Column(length = 100)
    private String city;

    @Column(length = 100)
    private String state;

    @Column(name = "cardinal_direction", length = 30)
    private String cardinalDirection;

    @Column(name = "direction_angle")
    private Double directionAngle; // 0 to 360 degrees orientation lens facing direction

    @Column(name = "fov_angle")
    private Double fovAngle; // Field of view capture spread angle width (e.g., 60°, 90°, 120°, 360°)

    @Column(name = "coverage_radius_meters")
    private Double coverageRadiusMeters;

    @Column(name = "installation_date")
    private LocalDate installationDate;

    @Column(name = "survey_date")
    private LocalDate surveyDate;

    @Enumerated(EnumType.STRING)
    @Column(name = "camera_status", nullable = false, length = 30)
    private CameraStatus cameraStatus = CameraStatus.ACTIVE;

    @Enumerated(EnumType.STRING)
    @Column(name = "verification_status", nullable = false, length = 30)
    private VerificationStatus verificationStatus = VerificationStatus.PENDING;

    @Column(name = "rejection_reason", columnDefinition = "TEXT")
    private String rejectionReason;

    @Column(name = "image_url", length = 500)
    private String imageUrl;

    @Column(name = "qr_code_url", length = 500)
    private String qrCodeUrl;

    @Column(name = "serial_number", length = 100)
    private String serialNumber;

    @Column(name = "owner_name", length = 150)
    private String ownerName;

    @Column(name = "owner_contact", length = 50)
    private String ownerContact;

    @Column(name = "owner_type", length = 50)
    private String ownerType;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "surveyor_id")
    private User surveyor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "police_station_id")
    private PoliceStation policeStation;
}
