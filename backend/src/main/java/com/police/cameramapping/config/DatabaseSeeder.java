package com.police.cameramapping.config;

import com.police.cameramapping.domain.model.*;
import com.police.cameramapping.domain.model.enums.*;
import com.police.cameramapping.domain.repository.*;
import lombok.RequiredArgsConstructor;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.PrecisionModel;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

@Component
@ConditionalOnProperty(name = "app.seeder.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
public class DatabaseSeeder implements CommandLineRunner {

    private static final Logger logger = LoggerFactory.getLogger(DatabaseSeeder.class);

    private final RoleRepository roleRepository;
    private final UserRepository userRepository;
    private final PoliceStationRepository policeStationRepository;
    private final CameraRepository cameraRepository;
    private final PasswordEncoder passwordEncoder;
    private final com.police.cameramapping.service.NagpurCameraSeederService nagpurCameraSeederService;
    private final com.police.cameramapping.service.NagpurInvestigationSeederService nagpurInvestigationSeederService;
    private final com.police.cameramapping.domain.repository.InvestigationCaseRepository investigationCaseRepository;

    private final GeometryFactory geometryFactory = new GeometryFactory(new PrecisionModel(), 4326);

    @Override
    public void run(String... args) {
        seedRoles();
        PoliceStation station = seedPoliceStation();
        User admin = seedAdminUser(station);
        User officer = seedOfficerUser(station);
        User surveyor = seedSurveyorUser(station);
        if (cameraRepository.count() < 50) {
            nagpurCameraSeederService.reseed50NagpurCameras();
        }
        if (investigationCaseRepository.count() < 8) {
            nagpurInvestigationSeederService.reseedNagpurInvestigations();
        }
    }

    private void seedRoles() {
        for (RoleEnum roleEnum : RoleEnum.values()) {
            if (roleRepository.findByName(roleEnum).isEmpty()) {
                roleRepository.save(Role.builder()
                        .name(roleEnum)
                        .description("System role for " + roleEnum.name())
                        .build());
                logger.info("Seeded role: {}", roleEnum);
            }
        }
    }

    private PoliceStation seedPoliceStation() {
        PoliceStation primaryStation = policeStationRepository.findByStationCode("PS-DEL-01")
                .orElseGet(() -> {
                    Point location = geometryFactory.createPoint(new Coordinate(77.2410, 28.6280));
                    PoliceStation station = PoliceStation.builder()
                            .stationCode("PS-DEL-01")
                            .stationName("Delhi Police Central Headquarters (ITO)")
                            .address("Jai Singh Road, ITO, New Delhi")
                            .contactNumber("+91-11-23490000")
                            .officerInCharge("Commissioner of Police")
                            .jurisdictionArea("Central Delhi & NDMC Zone")
                            .latitude(28.6280)
                            .longitude(77.2410)
                            .locationGeom(location)
                            .build();
                    logger.info("Seeded Police Station: Delhi Police HQ");
                    return policeStationRepository.save(station);
                });

        // Seed Pan-India Metropolitan & District Local Police Stations (Thanasa) - CCTNS Verified
        // Delhi NCR
        seedStationIfAbsent("PS-DEL-02", "Connaught Place Police Station", "Parliament Street, CP, New Delhi", "+91-11-23340000", "Central Delhi", 28.6328, 77.2197, "Delhi Police Bureau", "New Delhi");
        seedStationIfAbsent("PS-DEL-03", "Chanakyapuri Police Station", "Nyaya Marg, Chanakyapuri, New Delhi", "+91-11-24100000", "Diplomatic Enclave", 28.5985, 77.1906, "Delhi Police Bureau", "New Delhi");
        seedStationIfAbsent("PS-DEL-04", "Karol Bagh Police Station", "Pusa Road, Karol Bagh, New Delhi", "+91-11-25720000", "Central Delhi West", 28.6517, 77.1906, "Delhi Police Bureau", "Central Delhi");
        seedStationIfAbsent("PS-DEL-05", "Hauz Khas Police Station", "Aurobindo Marg, Hauz Khas, New Delhi", "+91-11-26510000", "South Delhi Zone", 28.5494, 77.2001, "Delhi Police Bureau", "South Delhi");
        seedStationIfAbsent("PS-DEL-06", "Saket Police Station", "Press Enclave Road, Saket, New Delhi", "+91-11-26850000", "South Delhi Courts", 28.5244, 77.2188, "Delhi Police Bureau", "South Delhi");
        seedStationIfAbsent("PS-DEL-07", "Dwarka Sector 23 Police Station", "Sector 23, Dwarka, New Delhi", "+91-11-28080000", "Dwarka Sub-City", 28.5611, 77.0543, "Delhi Police Bureau", "South West Delhi");
        seedStationIfAbsent("PS-NOIDA-01", "Noida Sector 20 Police Station", "Sector 20, Noida, UP", "+91-120-2520000", "Gautam Buddha Nagar", 28.5830, 77.3200, "Uttar Pradesh Police", "Gautam Buddha Nagar");
        seedStationIfAbsent("PS-GUR-01", "Gurugram DLF Phase 2 Police Station", "DLF Phase 2, Gurugram, HR", "+91-124-2350000", "Gurugram Cyber Hub", 28.4811, 77.0867, "Haryana Police", "Gurugram");

        // Mumbai & Thane
        seedStationIfAbsent("PS-MUM-01", "Mumbai City Police Commissionerate HQ", "Crawford Market, Fort, Mumbai", "+91-22-22620111", "Greater Mumbai", 18.9452, 72.8336, "Maharashtra State Police", "Mumbai City");
        seedStationIfAbsent("PS-MUM-02", "Colaba Police Station", "Shahid Bhagat Singh Road, Colaba, Mumbai", "+91-22-22850000", "South Mumbai", 18.9150, 72.8258, "Maharashtra State Police", "Mumbai City");
        seedStationIfAbsent("PS-MUM-03", "Marine Drive Police Station", "Netaji Subhash Chandra Bose Road, Mumbai", "+91-22-22810000", "Marine Drive", 18.9392, 72.8236, "Maharashtra State Police", "Mumbai City");
        seedStationIfAbsent("PS-MUM-04", "Bandra West Police Station", "Hill Road, Bandra West, Mumbai", "+91-22-26422000", "Western Suburbs", 19.0596, 72.8295, "Maharashtra State Police", "Mumbai Suburban");
        seedStationIfAbsent("PS-MUM-05", "Juhu Police Station", "JVPD Scheme, Juhu, Mumbai", "+91-22-26180000", "Juhu & Vile Parle", 19.1025, 72.8267, "Maharashtra State Police", "Mumbai Suburban");
        seedStationIfAbsent("PS-MUM-06", "Andheri East Police Station", "Old Nagardas Road, Andheri East, Mumbai", "+91-22-28320000", "Andheri Commercial", 19.1197, 72.8464, "Maharashtra State Police", "Mumbai Suburban");
        seedStationIfAbsent("PS-MUM-07", "Powai Police Station", "Central Avenue, Powai, Mumbai", "+91-22-25700000", "IIT Powai Zone", 19.1176, 72.9050, "Maharashtra State Police", "Mumbai Suburban");

        // Bengaluru
        seedStationIfAbsent("PS-BLR-01", "Bengaluru City Police HQ", "Infantry Road, Bengaluru", "+91-80-22942222", "Bengaluru Urban", 12.9818, 77.5975, "Karnataka State Police", "Bengaluru Urban");
        seedStationIfAbsent("PS-BLR-02", "Cubbon Park Police Station", "Kasturba Road, Bengaluru", "+91-80-22942230", "Central Business District", 12.9763, 77.5929, "Karnataka State Police", "Bengaluru Urban");
        seedStationIfAbsent("PS-BLR-03", "Indiranagar Police Station", "100 Feet Road, Indiranagar, Bengaluru", "+91-80-22942520", "East Zone", 12.9784, 77.6408, "Karnataka State Police", "Bengaluru Urban");
        seedStationIfAbsent("PS-BLR-04", "Koramangala Police Station", "80 Feet Road, Koramangala, Bengaluru", "+91-80-22942540", "South-East Tech Hub", 12.9352, 77.6245, "Karnataka State Police", "Bengaluru Urban");
        seedStationIfAbsent("PS-BLR-05", "Electronic City Police Station", "Hosur Road, Electronic City, Bengaluru", "+91-80-22943300", "Electronic City Zone", 12.8452, 77.6602, "Karnataka State Police", "Bengaluru Urban");
        seedStationIfAbsent("PS-BLR-06", "Whitefield Police Station", "Whitefield Main Road, Bengaluru", "+91-80-22942560", "ITPB Corridor", 12.9698, 77.7499, "Karnataka State Police", "Bengaluru Urban");

        // Hyderabad & Cyberabad
        seedStationIfAbsent("PS-HYD-01", "Hyderabad City Police HQ", "Basheerbagh, Hyderabad", "+91-40-27852435", "Hyderabad Central", 17.3985, 78.4746, "Telangana State Police", "Hyderabad");
        seedStationIfAbsent("PS-HYD-02", "Banjara Hills Police Station", "Road No. 12, Banjara Hills, Hyderabad", "+91-40-27852445", "Banjara Hills Zone", 17.4156, 78.4347, "Telangana State Police", "Hyderabad");
        seedStationIfAbsent("PS-HYD-03", "Jubilee Hills Police Station", "Road No. 36, Jubilee Hills, Hyderabad", "+91-40-27852450", "Jubilee Hills Zone", 17.4319, 78.4071, "Telangana State Police", "Hyderabad");
        seedStationIfAbsent("PS-HYD-04", "Cyberabad Police HQ (Gachibowli)", "Gachibowli, Hyderabad", "+91-40-27853400", "Cyberabad IT Zone", 17.4401, 78.3489, "Telangana State Police", "Rangareddy");

        // Kolkata
        seedStationIfAbsent("PS-KOL-01", "Lalbazar Kolkata Police HQ", "Lalbazar Street, BBD Bagh, Kolkata", "+91-33-22143000", "Kolkata Central", 22.5726, 88.3512, "West Bengal Police", "Kolkata");
        seedStationIfAbsent("PS-KOL-02", "Park Street Police Station", "Park Street, Kolkata", "+91-33-22290000", "Park Street Zone", 22.5532, 88.3533, "West Bengal Police", "Kolkata");
        seedStationIfAbsent("PS-KOL-03", "Bidhannagar Salt Lake Police Station", "Salt Lake Sector 1, Kolkata", "+91-33-23340000", "Salt Lake IT Hub", 22.5804, 88.4187, "West Bengal Police", "North 24 Parganas");

        // Chennai
        seedStationIfAbsent("PS-CHE-01", "Greater Chennai Police HQ", "Vepery, High Road, Chennai", "+91-44-23452320", "Chennai Central", 13.0878, 80.2642, "Tamil Nadu Police", "Chennai");
        seedStationIfAbsent("PS-CHE-02", "Anna Nagar Police Station", "2nd Avenue, Anna Nagar, Chennai", "+91-44-23452400", "North-West Chennai", 13.0850, 80.2100, "Tamil Nadu Police", "Chennai");
        seedStationIfAbsent("PS-CHE-03", "T. Nagar Police Station", "Venkatnarayana Road, T. Nagar, Chennai", "+91-44-23452420", "Commercial Shopping Hub", 13.0418, 80.2341, "Tamil Nadu Police", "Chennai");

        // Nagpur City Police (NGP HQ & Local Stations)
        seedStationIfAbsent("PS-NGP-01", "Nagpur Police Commissionerate HQ", "Civil Lines, Nagpur, MH", "+91-712-2560300", "Nagpur City Police Zone", 21.1524, 79.0801, "Maharashtra State Police", "Nagpur Urban");
        seedStationIfAbsent("PS-NGP-02", "Sitabuldi Police Station", "Main Road, Sitabuldi, Nagpur", "+91-712-2522000", "Central Nagpur Zone", 21.1458, 79.0882, "Maharashtra State Police", "Nagpur Urban");
        seedStationIfAbsent("PS-NGP-03", "Sadar Police Station", "Sadar Bazaar, Nagpur", "+91-712-2531000", "North Nagpur Zone", 21.1620, 79.0780, "Maharashtra State Police", "Nagpur Urban");
        seedStationIfAbsent("PS-NGP-04", "Ambazari Police Station", "Near Ambazari Lake, Nagpur", "+91-712-2542000", "West Nagpur Zone", 21.1350, 79.0550, "Maharashtra State Police", "Nagpur Urban");
        seedStationIfAbsent("PS-NGP-05", "Dharampeth Police Station", "WHC Road, Dharampeth, Nagpur", "+91-712-2553000", "Dharampeth Commercial Zone", 21.1410, 79.0680, "Maharashtra State Police", "Nagpur Urban");
        seedStationIfAbsent("PS-NGP-06", "Mankapur Police Station", "Ring Road, Mankapur, Nagpur", "+91-712-2584000", "Mankapur Zone", 21.1850, 79.0720, "Maharashtra State Police", "Nagpur Urban");
        seedStationIfAbsent("PS-NGP-07", "Koradi Police Station", "Koradi Road, Nagpur", "+91-712-2615000", "North Nagpur Suburbs", 21.2310, 79.0910, "Maharashtra State Police", "Nagpur District");

        // Pune, Ahmedabad, Jaipur, Lucknow, Chandigarh, Goa, Kochi
        seedStationIfAbsent("PS-PUN-01", "Shivajinagar Pune Police Station", "FC Road, Shivajinagar, Pune", "+91-20-25530000", "Pune Urban", 18.5308, 73.8474, "Maharashtra State Police", "Pune");
        seedStationIfAbsent("PS-AMD-01", "Satellite Ahmedabad Police Station", "SG Highway, Satellite, Ahmedabad", "+91-79-26920000", "West Ahmedabad", 23.0274, 72.5186, "Gujarat Police", "Ahmedabad");
        seedStationIfAbsent("PS-JAI-01", "Vaishali Nagar Jaipur Police Station", "Vaishali Nagar, Jaipur", "+91-141-2350000", "Jaipur West", 26.9124, 75.7433, "Rajasthan Police", "Jaipur");
        seedStationIfAbsent("PS-LUK-01", "Hazratganj Lucknow Police Station", "Hazratganj, Lucknow, UP", "+91-522-2230000", "Lucknow Central", 26.8500, 80.9500, "Uttar Pradesh Police", "Lucknow");
        seedStationIfAbsent("PS-CHA-01", "Sector 17 Chandigarh Police Station", "Sector 17, Chandigarh", "+91-172-2700000", "UT Chandigarh", 30.7400, 76.7800, "Chandigarh Police", "UT Chandigarh");
        seedStationIfAbsent("PS-GOA-01", "Panaji Town Police Station", "MG Road, Panaji, Goa", "+91-832-2420000", "North Goa Capital", 15.4989, 73.8278, "Goa Police", "North Goa");
        seedStationIfAbsent("PS-KOC-01", "Fort Kochi Police Station", "KB Jacob Road, Fort Kochi, Kerala", "+91-484-2215000", "Kochi Heritage Zone", 9.9656, 76.2424, "Kerala Police", "Ernakulam");

        return primaryStation;
    }

    private void seedStationIfAbsent(String code, String name, String address, String phone, String jurisdiction, double lat, double lng, String stateBureau, String district) {
        if (policeStationRepository.findByStationCode(code).isEmpty()) {
            Point loc = geometryFactory.createPoint(new Coordinate(lng, lat));
            policeStationRepository.save(PoliceStation.builder()
                    .stationCode(code)
                    .stationName(name)
                    .address(address)
                    .contactNumber(phone)
                    .officerInCharge("Station House Officer (SHO)")
                    .jurisdictionArea(jurisdiction)
                    .latitude(lat)
                    .longitude(lng)
                    .cctnsStationId("CCTNS-" + code)
                    .stateBureau(stateBureau)
                    .district(district)
                    .isCctnsVerified(true)
                    .locationGeom(loc)
                    .build());
            logger.info("Seeded CCTNS Synced Station: {} [{}]", name, code);
        }
    }

    private User seedAdminUser(PoliceStation station) {
        return userRepository.findByUsername("admin").orElseGet(() -> {
            Role adminRole = roleRepository.findByName(RoleEnum.ROLE_ADMIN).orElseThrow();
            User admin = User.builder()
                    .username("admin")
                    .email("admin@police.gov")
                    .password(passwordEncoder.encode("admin123"))
                    .fullName("System Administrator")
                    .phone("+91-9876543210")
                    .badgeNumber("ADM-001")
                    .role(adminRole)
                    .policeStation(station)
                    .isActive(true)
                    .build();
            logger.info("Seeded default admin user for development");
            return userRepository.save(admin);
        });
    }

    private User seedOfficerUser(PoliceStation station) {
        return userRepository.findByUsername("officer1").orElseGet(() -> {
            Role officerRole = roleRepository.findByName(RoleEnum.ROLE_POLICE_OFFICER).orElseThrow();
            User officer = User.builder()
                    .username("officer1")
                    .email("officer1@police.gov")
                    .password(passwordEncoder.encode("officer123"))
                    .fullName("Officer Vikram Sharma")
                    .phone("+91-9876543211")
                    .badgeNumber("POL-4092")
                    .role(officerRole)
                    .policeStation(station)
                    .isActive(true)
                    .build();
            logger.info("Seeded default police officer user for development");
            return userRepository.save(officer);
        });
    }

    private User seedSurveyorUser(PoliceStation station) {
        return userRepository.findByUsername("surveyor1").orElseGet(() -> {
            Role surveyorRole = roleRepository.findByName(RoleEnum.ROLE_SURVEY_PERSON).orElseThrow();
            User surveyor = User.builder()
                    .username("surveyor1")
                    .email("surveyor1@police.gov")
                    .password(passwordEncoder.encode("surveyor123"))
                    .fullName("Field Surveyor Amit Patel")
                    .phone("+91-9876543212")
                    .badgeNumber("SRV-102")
                    .role(surveyorRole)
                    .policeStation(station)
                    .isActive(true)
                    .build();
            logger.info("Seeded default surveyor user for development");
            return userRepository.save(surveyor);
        });
    }

    private void seedSampleCameras(PoliceStation station, User surveyor) {
        if (cameraRepository.count() > 10) return;

        Object[][] sampleData = {
                // Delhi
                {"CAM-001", "Connaught Place North Junction", CameraType.PTZ, 28.6159, 77.2100, 45.0, 150.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "Connaught Place, Central Delhi", "Central Delhi Zone", "Shopkeepers Association", "+91 98765 11111"},
                {"CAM-002", "Metro Station Gate 2 Traffic Dome", CameraType.DOME, 28.6129, 77.2120, 180.0, 80.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "Metro Gate 2, CP, New Delhi", "CP Sector 2", "DMRC Metro Security", "+91 98765 22222"},
                {"CAM-003", "Main Boulevard ANPR Gate", CameraType.ANPR, 28.6179, 77.2070, 90.0, 200.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "Parliament Street, New Delhi", "Government Complex", "Delhi Traffic Police", "+91 98765 33333"},
                
                // Nagpur (NGP)
                {"CAM-NGP-101", "Nagpur Sitabuldi Main Square Dome", CameraType.DOME, 21.1458, 79.0882, 90.0, 120.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "Sitabuldi Main Market Square, Nagpur, Maharashtra", "Nagpur Central", "Sitabuldi Traders Union", "+91 98711 44444"},
                {"CAM-NGP-102", "Nagpur Sadar Bazaar Traffic PTZ", CameraType.PTZ, 21.1620, 79.0780, 45.0, 150.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "Sadar Commercial Area, Nagpur, Maharashtra", "Nagpur North", "Sadar Plaza Association", "+91 98711 55555"},
                {"CAM-NGP-103", "Nagpur Ambazari Lake Entrance ANPR", CameraType.ANPR, 21.1350, 79.0550, 180.0, 200.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "Ambazari Lake Outer Road, Nagpur, Maharashtra", "Nagpur West", "Nagpur Smart City Corp", "+91 98711 66666"},
                {"CAM-NGP-104", "Nagpur Dharampeth Commercial Dome", CameraType.DOME, 21.1410, 79.0680, 270.0, 100.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "West High Court Road, Dharampeth, Nagpur", "Nagpur Dharampeth", "Apex Retail Store", "+91 98711 77777"},

                // Mumbai
                {"CAM-MUM-201", "Marine Drive Promenade Bullet Cam", CameraType.BULLET, 18.9392, 72.8236, 120.0, 150.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "Marine Drive Promenade, Fort, Mumbai", "South Mumbai", "BMC Coastal Command", "+91 98200 88888"},
                {"CAM-MUM-202", "Bandra Hill Road Market Dome", CameraType.DOME, 19.0596, 72.8295, 60.0, 100.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "Hill Road Shopping Junction, Bandra West, Mumbai", "Bandra West", "Bandra Merchants Guild", "+91 98200 99999"},

                // Bengaluru
                {"CAM-BLR-301", "Indiranagar 100ft Road ANPR", CameraType.ANPR, 12.9784, 77.6408, 90.0, 180.0, CameraStatus.ACTIVE, VerificationStatus.APPROVED, "100 Feet Road Junction, Indiranagar, Bengaluru", "Indiranagar East", "BBMP Smart Infra", "+91 98450 12345"}
        };

        for (Object[] item : sampleData) {
            String code = (String) item[0];
            String name = (String) item[1];
            CameraType type = (CameraType) item[2];
            double lat = (double) item[3];
            double lon = (double) item[4];
            double dir = (double) item[5];
            double radius = (double) item[6];
            CameraStatus status = (CameraStatus) item[7];
            VerificationStatus vStatus = (VerificationStatus) item[8];
            String address = (String) item[9];
            String area = (String) item[10];
            String ownerName = (String) item[11];
            String ownerContact = (String) item[12];

            Point geom = geometryFactory.createPoint(new Coordinate(lon, lat));

            if (cameraRepository.findByCameraCode(code).isEmpty()) {
                String serialNumber = "SN-" + code.replace("CAM-", "CCTV-");
                Camera cam = Camera.builder()
                        .cameraCode(code)
                        .serialNumber(serialNumber)
                        .cameraName(name)
                        .cameraType(type)
                        .latitude(lat)
                        .longitude(lon)
                        .locationGeom(geom)
                        .fullAddress(address)
                        .area(area)
                        .ward("Ward 1")
                        .zone(area)
                        .directionAngle(dir)
                        .coverageRadiusMeters(radius)
                        .installationDate(LocalDate.now().minusMonths(6))
                        .surveyDate(LocalDate.now().minusDays(10))
                        .cameraStatus(status)
                        .verificationStatus(vStatus)
                        .ownerName(ownerName)
                        .ownerContact(ownerContact)
                        .ownerType("COMMERCIAL")
                        .policeStation(station)
                        .surveyor(surveyor)
                        .build();

                cameraRepository.save(cam);
            }
        }

        logger.info("Seeded sample cameras across Nagpur, Delhi, Mumbai, and Bengaluru with geospatial coordinates");
    }
}
