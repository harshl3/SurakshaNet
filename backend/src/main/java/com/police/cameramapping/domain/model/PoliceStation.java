package com.police.cameramapping.domain.model;

import jakarta.persistence.*;
import lombok.*;
import org.locationtech.jts.geom.Point;

@Entity
@Table(name = "police_stations")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PoliceStation extends BaseEntity {

    @Column(name = "station_code", nullable = false, unique = true, length = 50)
    private String stationCode;

    @Column(name = "station_name", nullable = false, length = 150)
    private String stationName;

    @Column(name = "address", columnDefinition = "TEXT")
    private String address;

    @Column(name = "contact_number", length = 20)
    private String contactNumber;

    @Column(name = "officer_in_charge", length = 100)
    private String officerInCharge;

    @Column(name = "jurisdiction_area", length = 150)
    private String jurisdictionArea;

    @Column(name = "latitude")
    private Double latitude;

    @Column(name = "longitude")
    private Double longitude;

    @Column(name = "cctns_station_id", length = 100)
    private String cctnsStationId;

    @Column(name = "state_bureau", length = 100)
    private String stateBureau;

    @Column(name = "district", length = 100)
    private String district;

    @Column(name = "is_cctns_verified")
    @Builder.Default
    private Boolean isCctnsVerified = true;

    @Column(name = "location_geom", columnDefinition = "geometry(Point,4326)")
    private Point locationGeom;
}
