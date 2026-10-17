package com.police.cameramapping.domain.repository;

import com.police.cameramapping.domain.model.InvestigationCase;
import com.police.cameramapping.domain.model.enums.CaseStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface InvestigationCaseRepository extends JpaRepository<InvestigationCase, Long>, JpaSpecificationExecutor<InvestigationCase> {
    Optional<InvestigationCase> findByCaseNumber(String caseNumber);
    Boolean existsByCaseNumber(String caseNumber);
    Page<InvestigationCase> findByAssignedOfficer_IdAndIsDeletedFalse(Long officerId, Pageable pageable);
    Page<InvestigationCase> findByPoliceStation_IdAndIsDeletedFalse(Long stationId, Pageable pageable);
    Page<InvestigationCase> findByIsDeletedFalse(Pageable pageable);
    long countByStatusAndIsDeletedFalse(CaseStatus status);
}
