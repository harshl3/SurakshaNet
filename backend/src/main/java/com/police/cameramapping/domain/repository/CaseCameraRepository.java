package com.police.cameramapping.domain.repository;

import com.police.cameramapping.domain.model.CaseCamera;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CaseCameraRepository extends JpaRepository<CaseCamera, Long> {
    List<CaseCamera> findByInvestigationCase_IdAndIsDeletedFalse(Long caseId);
    Boolean existsByInvestigationCase_IdAndCamera_Id(Long caseId, Long cameraId);
}
