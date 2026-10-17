package com.police.cameramapping.domain.repository;

import com.police.cameramapping.domain.model.PoliceStation;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PoliceStationRepository extends JpaRepository<PoliceStation, Long>, JpaSpecificationExecutor<PoliceStation> {
    Optional<PoliceStation> findByStationCode(String stationCode);
    Boolean existsByStationCode(String stationCode);
    Page<PoliceStation> findByIsDeletedFalse(Pageable pageable);
}
