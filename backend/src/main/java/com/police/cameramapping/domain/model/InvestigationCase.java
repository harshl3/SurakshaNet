package com.police.cameramapping.domain.model;

import com.police.cameramapping.domain.model.enums.CaseStatus;
import jakarta.persistence.*;
import lombok.*;
import org.locationtech.jts.geom.Point;

import java.time.LocalDateTime;

@Entity
@Table(name = "investigation_cases")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class InvestigationCase extends BaseEntity {

    @Column(name = "case_number", nullable = false, unique = true, length = 50)
    private String caseNumber;

    @Column(name = "fir_number", length = 50)
    private String firNumber;

    @Column(nullable = false, length = 200)
    private String title;

    @Column(name = "crime_type", nullable = false, length = 100)
    private String crimeType;

    @Column(name = "crime_location_name", length = 255)
    private String crimeLocationName;

    @Column(nullable = false)
    private Double latitude;

    @Column(nullable = false)
    private Double longitude;

    @Column(name = "crime_location_geom", columnDefinition = "geometry(Point,4326)", nullable = false)
    private Point crimeLocationGeom;

    @Column(name = "incident_date", nullable = false)
    private LocalDateTime incidentDate;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private CaseStatus status = CaseStatus.OPEN;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_officer_id", nullable = false)
    private User assignedOfficer;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "police_station_id", nullable = false)
    private PoliceStation policeStation;
}
