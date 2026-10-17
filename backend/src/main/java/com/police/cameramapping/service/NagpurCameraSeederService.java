package com.police.cameramapping.service;

import com.police.cameramapping.domain.model.Camera;
import com.police.cameramapping.domain.model.PoliceStation;
import com.police.cameramapping.domain.model.User;
import com.police.cameramapping.domain.model.enums.CameraStatus;
import com.police.cameramapping.domain.model.enums.CameraType;
import com.police.cameramapping.domain.model.enums.VerificationStatus;
import com.police.cameramapping.domain.repository.CameraRepository;
import com.police.cameramapping.domain.repository.CaseCameraRepository;
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

import java.time.LocalDate;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class NagpurCameraSeederService {

    private final CameraRepository cameraRepository;
    private final CaseCameraRepository caseCameraRepository;
    private final PoliceStationRepository policeStationRepository;
    private final UserRepository userRepository;

    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    /**
     * Deletes all existing cameras and seeds exactly 50 realistic CCTV surveillance cameras
     * across Nagpur metropolitan area with complete parameters.
     */
    @Transactional
    public List<Camera> reseed50NagpurCameras() {
        log.info("Starting purge of existing cameras and reseeding 50 realistic Nagpur cameras...");

        // 1. Clean existing associations in case_cameras to maintain FK integrity
        try {
            caseCameraRepository.deleteAll();
            log.info("Cleared existing case_camera links.");
        } catch (Exception e) {
            log.warn("Notice during case_cameras cleanup: {}", e.getMessage());
        }

        // 2. Delete all existing cameras
        cameraRepository.deleteAll();
        log.info("Purged all existing cameras from database.");

        // 3. Resolve Nagpur Police Stations
        Map<String, PoliceStation> stationMap = new HashMap<>();
        policeStationRepository.findAll().forEach(ps -> stationMap.put(ps.getStationCode(), ps));

        PoliceStation fallbackStation = stationMap.getOrDefault("PS-NGP-01", 
                policeStationRepository.findAll().stream().findFirst().orElse(null));

        // 4. Resolve Surveyor & Admin Users
        User surveyor = userRepository.findByUsername("surveyor1")
                .orElseGet(() -> userRepository.findByUsername("admin").orElse(null));

        // 5. Raw Data Specification for 50 Realistic Nagpur Cameras
        // Index mapping:
        // 0: code, 1: serial, 2: name, 3: type, 4: lat, 5: lng, 6: address, 7: area, 8: ward, 9: zone,
        // 10: cardinal, 11: dirAngle, 12: fovAngle, 13: radius, 14: installMonthsAgo, 15: surveyDaysAgo,
        // 16: status, 17: vStatus, 18: rejectionReason, 19: ownerName, 20: ownerPhone, 21: ownerType, 22: stationCode
        Object[][] nagpurCams = new Object[][]{
            // --- 1. Sitabuldi & Central Nagpur Hub ---
            {"CAM-NGP-001", "SN-NGP-HIK-2023-001", "Sitabuldi Interchange Metro Station Gate 1", CameraType.ANPR, 21.1462, 79.0855,
             "Sitabuldi Interchange Station, Wardha Road, Sitabuldi, Nagpur, Maharashtra - 440012", "Sitabuldi", "Ward 1 - Sitabuldi", "Zone 10 - Central",
             "EAST", 90.0, 75.0, 180.0, 18, 12, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Maha Metro Rail Corporation", "+91 98220 11001", "GOVERNMENT", "PS-NGP-02"},

            {"CAM-NGP-002", "SN-NGP-CPP-2023-002", "Sitabuldi Main Road Variety Square Traffic Dome", CameraType.DOME, 21.1448, 79.0832,
             "Variety Square, Main Road, Sitabuldi, Nagpur, Maharashtra - 440012", "Sitabuldi", "Ward 1 - Sitabuldi", "Zone 10 - Central",
             "SOUTH_EAST", 135.0, 90.0, 90.0, 14, 8, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Sitabuldi Merchants Association", "+91 98220 11002", "COMMERCIAL", "PS-NGP-02"},

            {"CAM-NGP-003", "SN-NGP-DAH-2023-003", "Munje Square Anand Talkies Crossing PTZ", CameraType.PTZ, 21.1435, 79.0890,
             "Munje Square, Anand Talkies Road, Sitabuldi, Nagpur, Maharashtra - 440012", "Sitabuldi", "Ward 1 - Sitabuldi", "Zone 10 - Central",
             "NORTH_EAST", 45.0, 60.0, 200.0, 22, 15, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur City Traffic Police Branch", "+91 712 2560301", "GOVERNMENT", "PS-NGP-02"},

            {"CAM-NGP-004", "SN-NGP-HIK-2023-004", "Eternity Mall Main Entrance & Forecourt", CameraType.BULLET, 21.1441, 79.0818,
             "Eternity Mall, Amravati Road, Variety Square, Sitabuldi, Nagpur, Maharashtra - 440012", "Sitabuldi", "Ward 1 - Sitabuldi", "Zone 10 - Central",
             "NORTH", 0.0, 60.0, 110.0, 10, 5, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Eternity Mall Security & Management", "+91 98220 11004", "COMMERCIAL", "PS-NGP-02"},

            {"CAM-NGP-005", "SN-NGP-CPP-2023-005", "Maharajbagh Zoo & Botanical Garden Gate", CameraType.DOME, 21.1420, 79.0760,
             "Maharajbagh Club Road, Near Agriculture College, Nagpur, Maharashtra - 440001", "Maharajbagh", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "WEST", 270.0, 90.0, 80.0, 26, 20, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "PDKV Agriculture University Administration", "+91 712 2554100", "GOVERNMENT", "PS-NGP-02"},

            {"CAM-NGP-006", "SN-NGP-HIK-2023-006", "Zero Mile Freedom Park Monument Perimeter", CameraType.BULLET, 21.1492, 79.0838,
             "Zero Mile Stone, Wardha Road, Civil Lines, Nagpur, Maharashtra - 440001", "Civil Lines", "Ward 8 - Civil Lines", "Zone 10 - Central",
             "SOUTH", 180.0, 60.0, 120.0, 16, 9, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Smart & Sustainable City Corp (NSSCDCL)", "+91 712 2565588", "GOVERNMENT", "PS-NGP-01"},

            {"CAM-NGP-007", "SN-NGP-DAH-2023-007", "Jhansi Rani Square Wardha Road Origin PTZ", CameraType.PTZ, 21.1398, 79.0815,
             "Jhansi Rani Laxmibai Chowk, Wardha Road, Sitabuldi, Nagpur, Maharashtra - 440012", "Sitabuldi", "Ward 1 - Sitabuldi", "Zone 10 - Central",
             "SOUTH", 190.0, 60.0, 170.0, 20, 14, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Traffic Police Department", "+91 712 2560302", "GOVERNMENT", "PS-NGP-02"},

            // --- 2. Civil Lines, High Court & Government Area ---
            {"CAM-NGP-008", "SN-NGP-HIK-2023-008", "Nagpur Police Commissionerate Main Gate Surveillance", CameraType.ANPR, 21.1524, 79.0801,
             "Nagpur Police Commissionerate HQ, Civil Lines, Nagpur, Maharashtra - 440001", "Civil Lines", "Ward 8 - Civil Lines", "Zone 10 - Central",
             "NORTH", 10.0, 60.0, 160.0, 30, 2, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Office of the Commissioner of Police Nagpur", "+91 712 2560300", "GOVERNMENT", "PS-NGP-01"},

            {"CAM-NGP-009", "SN-NGP-AXI-2023-009", "Bombay High Court Nagpur Bench Gate 2", CameraType.PTZ, 21.1555, 79.0772,
             "Bombay High Court Bench, High Court Road, Civil Lines, Nagpur, Maharashtra - 440001", "Civil Lines", "Ward 8 - Civil Lines", "Zone 10 - Central",
             "NORTH_EAST", 55.0, 60.0, 190.0, 24, 6, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "High Court Security & Protocol Branch", "+91 712 2564200", "GOVERNMENT", "PS-NGP-01"},

            {"CAM-NGP-010", "SN-NGP-HIK-2023-010", "Vidhan Bhavan VIP Access Gate (Winter Session)", CameraType.DOME, 21.1508, 79.0789,
             "Maharashtra Legislative Assembly Vidhan Bhavan, Civil Lines, Nagpur - 440001", "Civil Lines", "Ward 8 - Civil Lines", "Zone 10 - Central",
             "EAST", 85.0, 90.0, 100.0, 28, 4, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Maharashtra State Protocol & Police VIP Security", "+91 712 2533000", "GOVERNMENT", "PS-NGP-01"},

            {"CAM-NGP-011", "SN-NGP-DAH-2023-011", "Reserve Bank of India (RBI) Square Kingsway", CameraType.ANPR, 21.1538, 79.0848,
             "RBI Square, Kingsway Road, Mohan Nagar, Nagpur, Maharashtra - 440001", "Civil Lines", "Ward 8 - Civil Lines", "Zone 10 - Central",
             "EAST", 90.0, 75.0, 200.0, 19, 11, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Reserve Bank of India Regional Security", "+91 712 2537000", "GOVERNMENT", "PS-NGP-01"},

            {"CAM-NGP-012", "SN-NGP-CPP-2023-012", "Kasturchand Park Metro Access Pavilion Dome", CameraType.DOME, 21.1518, 79.0862,
             "Kasturchand Park North Ground, Station Road, Nagpur, Maharashtra - 440001", "Civil Lines", "Ward 8 - Civil Lines", "Zone 10 - Central",
             "SOUTH_EAST", 140.0, 90.0, 85.0, 12, 7, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Maha Metro Station Facilities Cell", "+91 98220 11012", "GOVERNMENT", "PS-NGP-01"},

            {"CAM-NGP-013", "SN-NGP-HIK-2023-013", "VCA Cricket Stadium Civil Lines Gate 1", CameraType.PTZ, 21.1568, 79.0735,
             "Vidarbha Cricket Association Stadium, Rabindranath Tagore Road, Civil Lines, Nagpur - 440001", "Civil Lines", "Ward 8 - Civil Lines", "Zone 10 - Central",
             "NORTH_WEST", 315.0, 60.0, 175.0, 25, 18, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Vidarbha Cricket Association (VCA)", "+91 712 2541900", "COMMERCIAL", "PS-NGP-01"},

            {"CAM-NGP-014", "SN-NGP-CPP-2023-014", "CP Club & Ladies Club Roundabout", CameraType.BULLET, 21.1592, 79.0682,
             "Central Provinces Club, Civil Lines, Nagpur, Maharashtra - 440001", "Civil Lines", "Ward 8 - Civil Lines", "Zone 10 - Central",
             "WEST", 260.0, 60.0, 95.0, 15, 10, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "CP Club Managing Committee", "+91 712 2560230", "COMMUNITY", "PS-NGP-01"},

            // --- 3. Sadar Commercial, Mankapur & Kamptee Road ---
            {"CAM-NGP-015", "SN-NGP-DAH-2023-015", "Sadar Residency Road Commercial T-Point", CameraType.PTZ, 21.1620, 79.0780,
             "Residency Road, Sadar Bazaar, Nagpur, Maharashtra - 440001", "Sadar", "Ward 5 - Sadar", "Zone 8 - Mangalwari",
             "NORTH", 0.0, 60.0, 160.0, 17, 13, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Sadar Commercial Traders Guild", "+91 98220 11015", "COMMERCIAL", "PS-NGP-03"},

            {"CAM-NGP-016", "SN-NGP-HIK-2023-016", "Mount Road Haldiram Sweets & Bakery Forecourt", CameraType.DOME, 21.1638, 79.0795,
             "Haldiram Building, Mount Road Extension, Sadar, Nagpur - 440001", "Sadar", "Ward 5 - Sadar", "Zone 8 - Mangalwari",
             "EAST", 80.0, 90.0, 75.0, 8, 3, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Haldiram Foods International Pvt Ltd", "+91 712 2545555", "COMMERCIAL", "PS-NGP-03"},

            {"CAM-NGP-017", "SN-NGP-HIK-2023-017", "Liberty Cinema Chowk Flyover Base ANPR", CameraType.ANPR, 21.1605, 79.0812,
             "Liberty Chowk, Residency Road, Sadar, Nagpur, Maharashtra - 440001", "Sadar", "Ward 5 - Sadar", "Zone 8 - Mangalwari",
             "NORTH_EAST", 40.0, 60.0, 180.0, 14, 9, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Traffic Police Department", "+91 712 2560303", "GOVERNMENT", "PS-NGP-03"},

            {"CAM-NGP-018", "SN-NGP-DAH-2023-018", "Kadbi Chowk Kamptee Road Elevated Junction", CameraType.PTZ, 21.1712, 79.0845,
             "Kadbi Chowk, Kamptee Road, Clark Town, Nagpur, Maharashtra - 440004", "Clark Town", "Ward 5 - Sadar", "Zone 8 - Mangalwari",
             "NORTH", 15.0, 60.0, 190.0, 21, 16, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Municipal Corporation", "+91 712 2567035", "GOVERNMENT", "PS-NGP-03"},

            {"CAM-NGP-019", "SN-NGP-CPP-2023-019", "Mankapur Indoor Sports Stadium Outer Gate", CameraType.BULLET, 21.1850, 79.0720,
             "Divisional Sports Complex, Koradi Road, Mankapur, Nagpur - 440030", "Mankapur", "Ward 34 - Mangalwari", "Zone 8 - Mangalwari",
             "WEST", 280.0, 60.0, 130.0, 23, 14, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Directorate of Sports & Youth Services Maharashtra", "+91 712 2580120", "GOVERNMENT", "PS-NGP-06"},

            {"CAM-NGP-020", "SN-NGP-HIK-2023-020", "Automotive Square Ring Road Toll Checkpost", CameraType.ANPR, 21.1985, 79.0980,
             "Automotive Square, Kamptee Road Outer Ring Road, Nagpur - 440026", "Automotive", "Ward 38 - Ashi Nagar", "Zone 9 - Ashi Nagar",
             "NORTH_EAST", 45.0, 60.0, 220.0, 11, 4, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Regional Transport Office (RTO Nagpur City)", "+91 712 2561122", "GOVERNMENT", "PS-NGP-06"},

            {"CAM-NGP-021", "SN-NGP-DAH-2023-021", "Jaripatka Main Dayanand Park Market Square", CameraType.DOME, 21.1780, 79.0910,
             "Dayanand Park Road, Jaripatka Market, Nagpur, Maharashtra - 440014", "Jaripatka", "Ward 34 - Mangalwari", "Zone 8 - Mangalwari",
             "SOUTH_WEST", 225.0, 90.0, 70.0, 13, 11, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Jaripatka Retail Merchants Syndicate", "+91 98220 11021", "COMMERCIAL", "PS-NGP-06"},

            // --- 4. Dharampeth & West High Court (WHC) Corridor ---
            {"CAM-NGP-022", "SN-NGP-CPP-2023-022", "Dharampeth WHC Road Coffee House Square", CameraType.PTZ, 21.1410, 79.0680,
             "West High Court Road, Coffee House Square, Dharampeth, Nagpur - 440010", "Dharampeth", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "WEST", 270.0, 60.0, 150.0, 16, 5, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Dharampeth Vyapari Mandal", "+91 98220 11022", "COMMERCIAL", "PS-NGP-05"},

            {"CAM-NGP-023", "SN-NGP-HIK-2023-023", "Children's Traffic Park East Gate Surveillance", CameraType.DOME, 21.1432, 79.0635,
             "Children Traffic Park Road, Dharampeth, Nagpur, Maharashtra - 440010", "Dharampeth", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "NORTH", 15.0, 90.0, 80.0, 9, 2, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Municipal Corporation Garden Dept", "+91 712 2567099", "GOVERNMENT", "PS-NGP-05"},

            {"CAM-NGP-024", "SN-NGP-CPP-2023-024", "Gokulpeth Market Vegetable Mandi T-Crossing", CameraType.DOME, 21.1395, 79.0605,
             "Gokulpeth Main Bazaar, West High Court Road, Nagpur - 440010", "Gokulpeth", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "SOUTH", 180.0, 90.0, 65.0, 15, 12, CameraStatus.UNDER_MAINTENANCE, VerificationStatus.APPROVED, null,
             "Gokulpeth APMC Sub-Committee", "+91 98220 11024", "COMMUNITY", "PS-NGP-05"},

            {"CAM-NGP-025", "SN-NGP-DAH-2023-025", "Shankar Nagar Square WHC & North Bazar Chowk", CameraType.ANPR, 21.1362, 79.0648,
             "Shankar Nagar Chowk, West High Court Road, Nagpur, Maharashtra - 440010", "Shankar Nagar", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "SOUTH_WEST", 210.0, 60.0, 180.0, 20, 8, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Traffic Police Department", "+91 712 2560304", "GOVERNMENT", "PS-NGP-05"},

            {"CAM-NGP-026", "SN-NGP-HIK-2023-026", "Laxmi Bhavan Square Ram Nagar Road Junction", CameraType.BULLET, 21.1450, 79.0575,
             "Laxmi Bhavan Chowk, Ram Nagar Road, Dharampeth Extension, Nagpur - 440010", "Ram Nagar", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "NORTH_WEST", 320.0, 60.0, 100.0, 18, 14, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "West Nagpur Citizens Civic Society", "+91 98220 11026", "RESIDENTIAL", "PS-NGP-05"},

            {"CAM-NGP-027", "SN-NGP-AXI-2023-027", "Law College Square Amravati Road Flyover Base", CameraType.PTZ, 21.1475, 79.0620,
             "Law College Chowk, Amravati Road (NH-53), Nagpur, Maharashtra - 440001", "Dharampeth", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "WEST", 265.0, 60.0, 210.0, 27, 21, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "National Highways Authority of India (NHAI)", "+91 712 2548811", "GOVERNMENT", "PS-NGP-05"},

            // --- 5. Ambazari, VNIT & Academic Zone ---
            {"CAM-NGP-028", "SN-NGP-DAH-2023-028", "Ambazari Lake Spillway Promenade & Garden", CameraType.PTZ, 21.1350, 79.0550,
             "Ambazari Lake Embankment, Ambazari Road, Nagpur, Maharashtra - 440033", "Ambazari", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "SOUTH", 170.0, 60.0, 190.0, 19, 13, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Municipal Corporation Lakes Wing", "+91 712 2567040", "GOVERNMENT", "PS-NGP-04"},

            {"CAM-NGP-029", "SN-NGP-HIK-2023-029", "VNIT South Ambazari Road Campus Main Gate", CameraType.ANPR, 21.1275, 79.0520,
             "Visvesvaraya National Institute of Technology, South Ambazari Road, Nagpur - 440010", "Ambazari", "Ward 12 - Laxmi Nagar", "Zone 1 - Laxmi Nagar",
             "EAST", 90.0, 60.0, 170.0, 22, 10, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "VNIT Campus Security Administration", "+91 712 2801200", "GOVERNMENT", "PS-NGP-04"},

            {"CAM-NGP-030", "SN-NGP-CPP-2023-030", "Bajaj Nagar Abhyankar Nagar T-Point Chowk", CameraType.DOME, 21.1288, 79.0625,
             "Abhyankar Nagar Main Road, Bajaj Nagar, Nagpur, Maharashtra - 440010", "Bajaj Nagar", "Ward 12 - Laxmi Nagar", "Zone 1 - Laxmi Nagar",
             "NORTH_EAST", 50.0, 90.0, 85.0, 11, 7, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Bajaj Nagar Residents Welfare Association", "+91 98220 11030", "RESIDENTIAL", "PS-NGP-04"},

            {"CAM-NGP-031", "SN-NGP-HIK-2023-031", "LIT University Campus Amravati Road Gate", CameraType.BULLET, 21.1485, 79.0430,
             "Laxminarayan Innovation Technological University, Amravati Road, Nagpur - 440033", "Bharat Nagar", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "WEST", 280.0, 60.0, 120.0, 14, 9, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "LIT University Security Cell", "+91 712 2561100", "GOVERNMENT", "PS-NGP-04"},

            {"CAM-NGP-032", "SN-NGP-DAH-2023-032", "Futala Lake Food Street Security Promenade", CameraType.PTZ, 21.1540, 79.0485,
             "Futala Lake Viewing Gallery, Vayusena Nagar, Nagpur, Maharashtra - 440001", "Futala", "Ward 2 - Dharampeth", "Zone 2 - Dharampeth",
             "NORTH_WEST", 330.0, 60.0, 200.0, 15, 6, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Smart City Development Corporation", "+91 712 2565500", "GOVERNMENT", "PS-NGP-04"},

            {"CAM-NGP-033", "SN-NGP-CPP-2023-033", "Seminary Hills TV Tower Forest Trailhead", CameraType.BULLET, 21.1685, 79.0555,
             "TV Tower Road, Seminary Hills Reserve Forest, Nagpur, Maharashtra - 440006", "Seminary Hills", "Ward 8 - Civil Lines", "Zone 8 - Mangalwari",
             "NORTH", 20.0, 60.0, 110.0, 24, 19, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Maharashtra Forest Department Nagpur Circle", "+91 712 2560800", "GOVERNMENT", "PS-NGP-03"},

            // --- 6. South Nagpur & Ring Road Corridor ---
            {"CAM-NGP-034", "SN-NGP-HIK-2023-034", "Pratap Nagar Ring Road Traffic Intersection", CameraType.ANPR, 21.1180, 79.0590,
             "Pratap Nagar Chowk, Outer Ring Road, Nagpur, Maharashtra - 440022", "Pratap Nagar", "Ward 12 - Laxmi Nagar", "Zone 1 - Laxmi Nagar",
             "SOUTH_EAST", 140.0, 60.0, 190.0, 17, 11, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Traffic Police Branch", "+91 712 2560305", "GOVERNMENT", "PS-NGP-04"},

            {"CAM-NGP-035", "SN-NGP-CPP-2023-035", "Deendayal Nagar Ring Road T-Point", CameraType.DOME, 21.1125, 79.0495,
             "Deendayal Nagar Ring Road Junction, Swavlambi Nagar, Nagpur - 440022", "Deendayal Nagar", "Ward 12 - Laxmi Nagar", "Zone 1 - Laxmi Nagar",
             "SOUTH_WEST", 230.0, 90.0, 90.0, 13, 8, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Deendayal Nagar Vikas Samiti", "+91 98220 11035", "RESIDENTIAL", "PS-NGP-04"},

            {"CAM-NGP-036", "SN-NGP-DAH-2023-036", "Trimurti Nagar Main Market Commercial Square", CameraType.PTZ, 21.1155, 79.0410,
             "Trimurti Nagar Main Road Chowk, Subhash Nagar Road, Nagpur - 440022", "Trimurti Nagar", "Ward 12 - Laxmi Nagar", "Zone 1 - Laxmi Nagar",
             "WEST", 270.0, 60.0, 160.0, 10, 4, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Trimurti Nagar Merchants Guild", "+91 98220 11036", "COMMERCIAL", "PS-NGP-04"},

            {"CAM-NGP-037", "SN-NGP-HIK-2023-037", "Jaitala Road Octroi Checkpost & Ring Road", CameraType.ANPR, 21.1040, 79.0320,
             "Jaitala Octroi Naka, Hingna Road Crossing, Nagpur, Maharashtra - 440036", "Jaitala", "Ward 12 - Laxmi Nagar", "Zone 1 - Laxmi Nagar",
             "SOUTH_WEST", 215.0, 60.0, 210.0, 20, 15, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Municipal Corporation Border Cell", "+91 712 2567088", "GOVERNMENT", "PS-NGP-04"},

            {"CAM-NGP-038", "SN-NGP-CPP-2023-038", "Khamla Sindhi Hindi High School Chowk", CameraType.DOME, 21.1215, 79.0695,
             "Khamla Main Market Road, Near Sindhi Hindi School, Nagpur - 440025", "Khamla", "Ward 12 - Laxmi Nagar", "Zone 1 - Laxmi Nagar",
             "EAST", 100.0, 90.0, 75.0, 16, 12, CameraStatus.ACTIVE, VerificationStatus.PENDING, null,
             "Khamla Traders Association", "+91 98220 11038", "COMMERCIAL", "PS-NGP-04"},

            {"CAM-NGP-039", "SN-NGP-DAH-2023-039", "Chhatrapati Square Wardha Road Elevated Flyover", CameraType.ANPR, 21.1130, 79.0765,
             "Chhatrapati Shivaji Maharaj Chowk, Wardha Road (NH-44), Nagpur - 440015", "Pratap Nagar", "Ward 16 - Hanuman Nagar", "Zone 3 - Hanuman Nagar",
             "SOUTH", 180.0, 60.0, 220.0, 25, 17, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "National Highways Authority of India (NH-44)", "+91 712 2549922", "GOVERNMENT", "PS-NGP-02"},

            {"CAM-NGP-040", "SN-NGP-HIK-2023-040", "Ujjwal Nagar Metro Station Wardha Road", CameraType.DOME, 21.1045, 79.0725,
             "Ujjwal Nagar Metro Station Concourse, Wardha Road, Nagpur - 440025", "Sonegaon", "Ward 16 - Hanuman Nagar", "Zone 3 - Hanuman Nagar",
             "SOUTH_WEST", 200.0, 90.0, 95.0, 14, 9, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Maha Metro Security Directorate", "+91 98220 11040", "GOVERNMENT", "PS-NGP-02"},

            // --- 7. East Nagpur, Railway, Itwari & Sakkardara ---
            {"CAM-NGP-041", "SN-NGP-AXI-2023-041", "Nagpur Railway Station West Entrance Plaza", CameraType.ANPR, 21.1528, 79.0905,
             "Nagpur Central Railway Station West Concourse, Station Road, Nagpur - 440001", "Station Area", "Ward 1 - Sitabuldi", "Zone 10 - Central",
             "WEST", 275.0, 60.0, 190.0, 32, 2, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Government Railway Police (GRP Maharashtra)", "+91 712 2564344", "GOVERNMENT", "PS-NGP-02"},

            {"CAM-NGP-042", "SN-NGP-CPP-2023-042", "Cotton Market Subzi Mandi Wholesale Yard", CameraType.DOME, 21.1480, 79.0945,
             "Cotton Market Wholesale Yard, Ghat Road, Nagpur, Maharashtra - 440018", "Cotton Market", "Ward 25 - Gandhibagh", "Zone 6 - Gandhibagh",
             "SOUTH_EAST", 125.0, 90.0, 90.0, 21, 14, CameraStatus.OFFLINE, VerificationStatus.REJECTED,
             "Camera optical sensor heavily obscured by market shed canopy and smoke; relocated pole required.",
             "APMC Nagpur Agricultural Market Board", "+91 712 2724400", "COMMERCIAL", "PS-NGP-02"},

            {"CAM-NGP-043", "SN-NGP-DAH-2023-043", "Gandhibagh Central Avenue Model Mills Chowk", CameraType.PTZ, 21.1510, 79.1025,
             "Central Avenue Road, Model Mills Chowk, Gandhibagh, Nagpur - 440018", "Gandhibagh", "Ward 25 - Gandhibagh", "Zone 6 - Gandhibagh",
             "EAST", 90.0, 60.0, 180.0, 18, 11, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Gandhibagh Wholesale Cloth Market Association", "+91 98220 11043", "COMMERCIAL", "PS-NGP-02"},

            {"CAM-NGP-044", "SN-NGP-HIK-2023-044", "Itwari Sarafa Bazaar Gold Bullion Market", CameraType.DOME, 21.1565, 79.1120,
             "Sarafa Bazaar Main Lane, Itwari Market, Nagpur, Maharashtra - 440002", "Itwari", "Ward 30 - Satranjipura", "Zone 7 - Satranjipura",
             "NORTH_EAST", 45.0, 90.0, 70.0, 22, 16, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Sarafa & Bullion Merchants Association", "+91 712 2768100", "COMMERCIAL", "PS-NGP-03"},

            {"CAM-NGP-045", "SN-NGP-CPP-2023-045", "Reshimbagh Ground Smruti Mandir Entrance", CameraType.PTZ, 21.1325, 79.1055,
             "Reshimbagh Road, Near Suresh Bhat Auditorium, Nagpur - 440009", "Reshimbagh", "Ward 21 - Nehru Nagar", "Zone 5 - Nehru Nagar",
             "NORTH", 0.0, 60.0, 175.0, 19, 13, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Dr. Hedgewar Smruti Mandir Trust", "+91 712 2743100", "COMMUNITY", "PS-NGP-02"},

            {"CAM-NGP-046", "SN-NGP-DAH-2023-046", "Sakkardara Lake & Garden Roundabout Crossing", CameraType.PTZ, 21.1245, 79.1125,
             "Sakkardara Square, Umred Road, Sakkardara, Nagpur, Maharashtra - 440024", "Sakkardara", "Ward 21 - Nehru Nagar", "Zone 5 - Nehru Nagar",
             "SOUTH_EAST", 130.0, 60.0, 180.0, 15, 8, CameraStatus.UNDER_MAINTENANCE, VerificationStatus.PENDING, null,
             "Nagpur Municipal Corporation Garden Dept", "+91 712 2567055", "GOVERNMENT", "PS-NGP-02"},

            {"CAM-NGP-047", "SN-NGP-HIK-2023-047", "Medical Square Government Medical College Gate", CameraType.ANPR, 21.1320, 79.0940,
             "Medical Square, Great Nag Road, GMC Hospital Campus, Nagpur - 440003", "Medical", "Ward 16 - Hanuman Nagar", "Zone 3 - Hanuman Nagar",
             "NORTH_WEST", 310.0, 60.0, 200.0, 26, 17, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Government Medical College & Hospital Security (GMCH)", "+91 712 2744100", "GOVERNMENT", "PS-NGP-02"},

            {"CAM-NGP-048", "SN-NGP-DAH-2023-048", "Manewada Ring Road Besa Chowk Traffic Point", CameraType.ANPR, 21.1015, 79.1005,
             "Manewada Ring Road Square, Besa Road Junction, Nagpur - 440027", "Manewada", "Ward 16 - Hanuman Nagar", "Zone 3 - Hanuman Nagar",
             "SOUTH_EAST", 150.0, 60.0, 190.0, 12, 7, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Nagpur Traffic Police Department", "+91 712 2560306", "GOVERNMENT", "PS-NGP-02"},

            // --- 8. Airport, Industrial & MIHAN SEZ Corridor ---
            {"CAM-NGP-049", "SN-NGP-AXI-2023-049", "Dr. Babasaheb Ambedkar Airport Terminal Access", CameraType.ANPR, 21.0920, 79.0620,
             "Nagpur International Airport Approach Road, Sonegaon, Nagpur - 440005", "Sonegaon", "Ward 16 - Hanuman Nagar", "Zone 3 - Hanuman Nagar",
             "NORTH", 10.0, 60.0, 200.0, 24, 6, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Airports Authority of India (MIHAN Airport Ltd)", "+91 712 2807501", "GOVERNMENT", "PS-NGP-04"},

            {"CAM-NGP-050", "SN-NGP-HIK-2023-050", "MIHAN SEZ Container Freight Depot Main Gate", CameraType.ANPR, 21.0625, 79.0480,
             "Multi-modal International Cargo Hub & Airport (MIHAN), Wardha Road (NH-44), Nagpur - 441108", "MIHAN", "Ward 16 - Hanuman Nagar", "Zone 3 - Hanuman Nagar",
             "SOUTH", 180.0, 60.0, 250.0, 29, 15, CameraStatus.ACTIVE, VerificationStatus.APPROVED, null,
             "Maharashtra Airport Development Company (MADC)", "+91 712 2552800", "GOVERNMENT", "PS-NGP-04"}
        };

        List<Camera> camerasToSave = new ArrayList<>();
        LocalDate today = LocalDate.now();

        for (Object[] row : nagpurCams) {
            String code = (String) row[0];
            String serial = (String) row[1];
            String name = (String) row[2];
            CameraType type = (CameraType) row[3];
            double lat = (Double) row[4];
            double lon = (Double) row[5];
            String address = (String) row[6];
            String area = (String) row[7];
            String ward = (String) row[8];
            String zone = (String) row[9];
            String cardinal = (String) row[10];
            double dirAngle = (Double) row[11];
            double fovAngle = (Double) row[12];
            double radius = (Double) row[13];
            int installMonths = (Integer) row[14];
            int surveyDays = (Integer) row[15];
            CameraStatus status = (CameraStatus) row[16];
            VerificationStatus vStatus = (VerificationStatus) row[17];
            String rejectionReason = (String) row[18];
            String ownerName = (String) row[19];
            String ownerPhone = (String) row[20];
            String ownerType = (String) row[21];
            String stationCode = (String) row[22];

            Point geom = geometryFactory.createPoint(new Coordinate(lon, lat));
            PoliceStation assignedStation = stationMap.getOrDefault(stationCode, fallbackStation);

            // Cloud CDN Image URL structure (Supabase Storage camera-media bucket)
            String filename = code.toLowerCase().replace("-", "_") + ".jpg";
            String imageUrl = "https://your-project-id.supabase.co/storage/v1/object/public/camera-media/" + filename;
            String qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=CCTV-" + code;

            Camera camera = Camera.builder()
                    .cameraCode(code)
                    .serialNumber(serial)
                    .cameraName(name)
                    .cameraType(type)
                    .latitude(lat)
                    .longitude(lon)
                    .locationGeom(geom)
                    .fullAddress(address)
                    .area(area)
                    .ward(ward)
                    .zone(zone)
                    .city("Nagpur")
                    .state("Maharashtra")
                    .cardinalDirection(cardinal)
                    .directionAngle(dirAngle)
                    .fovAngle(fovAngle)
                    .coverageRadiusMeters(radius)
                    .installationDate(today.minusMonths(installMonths))
                    .surveyDate(today.minusDays(surveyDays))
                    .cameraStatus(status)
                    .verificationStatus(vStatus)
                    .rejectionReason(rejectionReason)
                    .imageUrl(imageUrl)
                    .qrCodeUrl(qrUrl)
                    .ownerName(ownerName)
                    .ownerContact(ownerPhone)
                    .ownerType(ownerType)
                    .policeStation(assignedStation)
                    .surveyor(surveyor)
                    .build();

            camerasToSave.add(camera);
        }

        List<Camera> savedCameras = cameraRepository.saveAll(camerasToSave);
        log.info("Successfully seeded {} realistic cameras in Nagpur city database!", savedCameras.size());
        return savedCameras;
    }
}
