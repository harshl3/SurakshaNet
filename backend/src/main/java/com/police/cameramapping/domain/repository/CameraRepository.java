package com.police.cameramapping.domain.repository;

import com.police.cameramapping.domain.model.Camera;
import com.police.cameramapping.domain.model.enums.CameraStatus;
import com.police.cameramapping.domain.model.enums.VerificationStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface CameraRepository extends JpaRepository<Camera, Long>, JpaSpecificationExecutor<Camera> {

    Optional<Camera> findByCameraCode(String cameraCode);

    Boolean existsByCameraCode(String cameraCode);

    Optional<Camera> findBySerialNumber(String serialNumber);

    Boolean existsBySerialNumber(String serialNumber);

    List<Camera> findByOwnerContactAndIsDeletedFalse(String ownerContact);

    @Query("SELECT c FROM Camera c WHERE c.isDeleted = false AND " +
           "(REPLACE(REPLACE(REPLACE(c.ownerContact, ' ', ''), '-', ''), '+91', '') LIKE CONCAT('%', :cleanContact, '%'))")
    List<Camera> searchByCleanContact(@Param("cleanContact") String cleanContact);

    Page<Camera> findByVerificationStatusAndIsDeletedFalse(VerificationStatus status, Pageable pageable);

    Page<Camera> findBySurveyor_IdAndIsDeletedFalse(Long surveyorId, Pageable pageable);

    long countByCameraStatusAndIsDeletedFalse(CameraStatus status);

    long countByVerificationStatusAndIsDeletedFalse(VerificationStatus status);

    /**
     * PostGIS Native Query to find cameras within radius (in meters) sorted by proximity.
     * Uses ST_DWithin and ST_DistanceSphere for fast GIS computation.
     */
    @Query(value = """
            SELECT c.*, 
                   ST_DistanceSphere(c.location_geom, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)) AS distance
            FROM cameras c
            WHERE c.is_deleted = false
              AND ST_DWithin(
                    CAST(c.location_geom AS geography), 
                    CAST(ST_SetSRID(ST_MakePoint(:lon, :lat), 4326) AS geography), 
                    :radiusMeters
                  )
            ORDER BY distance ASC
            """, nativeQuery = true)
    List<Camera> findNearbyCameras(
            @Param("lat") double latitude,
            @Param("lon") double longitude,
            @Param("radiusMeters") double radiusMeters
    );
}
