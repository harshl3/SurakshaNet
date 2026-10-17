package com.police.cameramapping.service;

import com.police.cameramapping.domain.model.Camera;
import com.police.cameramapping.domain.model.CaseCamera;
import com.police.cameramapping.domain.model.InvestigationCase;
import com.police.cameramapping.domain.model.PoliceStation;
import com.police.cameramapping.domain.model.User;
import com.police.cameramapping.domain.model.enums.CaseStatus;
import com.police.cameramapping.domain.repository.CameraRepository;
import com.police.cameramapping.domain.repository.CaseCameraRepository;
import com.police.cameramapping.domain.repository.InvestigationCaseRepository;
import com.police.cameramapping.domain.repository.PoliceStationRepository;
import com.police.cameramapping.domain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class NagpurInvestigationSeederService {

    private final InvestigationCaseRepository investigationCaseRepository;
    private final CaseCameraRepository caseCameraRepository;
    private final CameraRepository cameraRepository;
    private final PoliceStationRepository policeStationRepository;
    private final UserRepository userRepository;

    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    /**
     * Purges all previous investigation records and seeds 8 realistic police investigations
     * across different sectors of Nagpur with authentic coordinates, FIR numbers, and PostGIS linked CCTV nodes.
     */
    @Transactional
    public List<InvestigationCase> reseedNagpurInvestigations() {
        log.info("Starting purge of existing investigation records and reseeding Nagpur cases...");

        // 1. Purge existing case-camera evidence links and cases
        caseCameraRepository.deleteAll();
        investigationCaseRepository.deleteAll();
        log.info("Purged existing case_cameras and investigation_cases from database.");

        // 2. Resolve default officer and police station for audit & permission integrity
        User officer = userRepository.findByUsername("officer1")
                .or(() -> userRepository.findByUsername("admin"))
                .orElseGet(() -> userRepository.findAll().stream().findFirst()
                        .orElseThrow(() -> new IllegalStateException("No user found in database to assign cases.")));

        PoliceStation sitabuldiStation = policeStationRepository.findByStationCode("PS-NGP-02")
                .or(() -> policeStationRepository.findByStationCode("PS-NGP-01"))
                .orElseGet(() -> policeStationRepository.findAll().stream().findFirst().orElse(null));

        // 3. Realistic Investigation Cases Data across Nagpur
        // Format: { caseNum, firNum, title, crimeType, locationName, lat, lng, incidentDate, description, status, radiusMeters, stationCode }
        Object[][] rawCases = {
                {
                        "CAS-NGP-2026-001",
                        "FIR-2026-STB-0142",
                        "Armed Robbery at Sitabuldi Metro Plaza Commercial Complex",
                        "ARMED_ROBBERY",
                        "Zero Mile Metro Interchange, Sitabuldi Market, Nagpur",
                        21.1466,
                        79.0882,
                        LocalDateTime.now().minusDays(1).withHour(21).withMinute(15),
                        "Two unidentified suspects on a black sports motorcycle broke into a high-end electronics retail shop at Sitabuldi Plaza. Escaped towards Variety Square. Immediate ANPR and PTZ footage triangulation requested.",
                        CaseStatus.OPEN,
                        500.0,
                        "PS-NGP-02"
                },
                {
                        "CAS-NGP-2026-002",
                        "FIR-2026-SDR-0089",
                        "Luxury SUV Theft Outside Sadar Commercial Promenade",
                        "VEHICLE_THEFT",
                        "Mount Road Ext, Sadar Bazaar, Nagpur",
                        21.1625,
                        79.0784,
                        LocalDateTime.now().minusDays(2).withHour(18).withMinute(45),
                        "White Toyota Fortuner (MH-31-EA-4412) stolen from outside Residency Club parking. Suspect entered vehicle using key cloning device. Trajectory traced heading north towards Katol Road bypass.",
                        CaseStatus.UNDER_INVESTIGATION,
                        750.0,
                        "PS-NGP-03"
                },
                {
                        "CAS-NGP-2026-003",
                        "FIR-2026-DPT-0215",
                        "Nocturnal Safe Breach at Dharampeth Bullion Market",
                        "BURGLARY",
                        "West High Court Road, Dharampeth, Nagpur",
                        21.1412,
                        79.0682,
                        LocalDateTime.now().minusDays(3).withHour(2).withMinute(30),
                        "Targeted burglary at bullion outlet on WHC Road between 02:30 and 03:45 AM. Power to store cut; perimeter CCTV and street-facing ANPR cameras requested to isolate pedestrian & vehicle movement.",
                        CaseStatus.OPEN,
                        600.0,
                        "PS-NGP-05"
                },
                {
                        "CAS-NGP-2026-004",
                        "FIR-2026-AMB-0311",
                        "Fatal Hit-and-Run Investigation on Ambazari Outer Ring Road",
                        "HIT_AND_RUN",
                        "Ambazari Lake Garden Promenade, Western Nagpur",
                        21.1298,
                        79.0495,
                        LocalDateTime.now().minusHours(14),
                        "Speeding dark sedan collided with a cyclist near Ambazari garden gate before fleeing towards Hingna MIDC connector. Forensic analysis of optical direction vectors underway.",
                        CaseStatus.OPEN,
                        1000.0,
                        "PS-NGP-04"
                },
                {
                        "CAS-NGP-2026-005",
                        "FIR-2026-ITW-0054",
                        "Dual-Suspect Chain Snatching in Itwari Wholesale Market",
                        "SNATCHING",
                        "Sarafa Oli, Itwari Commercial Ward, Nagpur",
                        21.1538,
                        79.1124,
                        LocalDateTime.now().minusDays(4).withHour(16).withMinute(20),
                        "Pillion rider snatched gold ornament from elderly pedestrian in crowded bazaar. Escaped through narrow alleyways towards Gandhibagh. CCTV node triangulation needed.",
                        CaseStatus.UNDER_INVESTIGATION,
                        400.0,
                        "PS-NGP-01"
                },
                {
                        "CAS-NGP-2026-006",
                        "FIR-2026-AJN-0178",
                        "Narcotics Distribution Drop Interception near Medical Square",
                        "NARCOTICS",
                        "GMC Medical Square Junction, Ajni, Nagpur",
                        21.1354,
                        79.0968,
                        LocalDateTime.now().minusDays(1).withHour(23).withMinute(10),
                        "Intelligence report of scheduled contraband exchange near Government Medical College outer gate. Target vehicle identified as silver auto-rickshaw with missing rear number plate.",
                        CaseStatus.OPEN,
                        650.0,
                        "PS-NGP-01"
                },
                {
                        "CAS-NGP-2026-007",
                        "FIR-2026-MHN-0023",
                        "Unauthorized Server Hardware Tampering at MIHAN IT SEZ",
                        "CYBER_ESPIONAGE",
                        "Central Avenue, MIHAN SEZ Infotech Zone, Nagpur",
                        21.0582,
                        79.0520,
                        LocalDateTime.now().minusDays(5).withHour(11).withMinute(0),
                        "Unauthorized personnel gained physical access to secondary server racks using cloned RFID badge. Correlating entrance ANPR and lobby dome camera timestamps.",
                        CaseStatus.UNDER_INVESTIGATION,
                        800.0,
                        "PS-NGP-01"
                },
                {
                        "CAS-NGP-2026-008",
                        "FIR-2026-KOT-0091",
                        "Commercial Waterfront Extortion Threat at Gandhisagar Lake",
                        "EXTORTION",
                        "Gandhisagar Lake Embankment, Mahal, Nagpur",
                        21.1442,
                        79.0998,
                        LocalDateTime.now().minusDays(6).withHour(19).withMinute(40),
                        "Multiple food stall vendors threatened by organized racketeers. Suspects captured on municipal pole camera at lake periphery. Suspects identified and apprehended.",
                        CaseStatus.CLOSED,
                        500.0,
                        "PS-NGP-02"
                }
        };

        List<InvestigationCase> savedCases = new ArrayList<>();

        for (Object[] item : rawCases) {
            String caseNum = (String) item[0];
            String firNum = (String) item[1];
            String title = (String) item[2];
            String crimeType = (String) item[3];
            String locationName = (String) item[4];
            double lat = (double) item[5];
            double lng = (double) item[6];
            LocalDateTime incidentDate = (LocalDateTime) item[7];
            String description = (String) item[8];
            CaseStatus status = (CaseStatus) item[9];
            double radiusMeters = (double) item[10];
            String stationCode = item.length > 11 ? (String) item[11] : null;

            PoliceStation caseStation = sitabuldiStation;
            if (stationCode != null) {
                caseStation = policeStationRepository.findByStationCode(stationCode)
                        .orElse(sitabuldiStation);
            }

            Point geom = geometryFactory.createPoint(new Coordinate(lng, lat));

            InvestigationCase c = InvestigationCase.builder()
                    .caseNumber(caseNum)
                    .firNumber(firNum)
                    .title(title)
                    .crimeType(crimeType)
                    .crimeLocationName(locationName)
                    .latitude(lat)
                    .longitude(lng)
                    .crimeLocationGeom(geom)
                    .incidentDate(incidentDate)
                    .description(description)
                    .status(status)
                    .assignedOfficer(officer)
                    .policeStation(caseStation)
                    .build();

            c.setCreatedBy(officer.getUsername());
            InvestigationCase savedCase = investigationCaseRepository.save(c);

            // Auto-link nearby CCTV cameras to this case using PostGIS spatial radius
            try {
                List<Camera> nearby = cameraRepository.findNearbyCameras(lat, lng, radiusMeters);
                for (Camera cam : nearby) {
                    CaseCamera link = CaseCamera.builder()
                            .investigationCase(savedCase)
                            .camera(cam)
                            .distanceMeters(null)
                            .evidenceNotes("Spatial proximity detection within " + radiusMeters + "m incident zone")
                            .isKeyEvidence(cam.getCameraType() != null && cam.getCameraType().name().contains("ANPR"))
                            .build();
                    link.setCreatedBy(officer.getUsername());
                    caseCameraRepository.save(link);
                }
                log.info("Linked {} CCTV nodes to investigation case {} [{}]", nearby.size(), caseNum, title);
            } catch (Exception e) {
                log.warn("PostGIS nearby camera linking warning for case {}: {}", caseNum, e.getMessage());
            }

            savedCases.add(savedCase);
        }

        log.info("Successfully seeded {} realistic investigation cases across Nagpur.", savedCases.size());
        return savedCases;
    }
}
