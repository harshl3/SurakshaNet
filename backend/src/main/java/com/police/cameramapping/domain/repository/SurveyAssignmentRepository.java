package com.police.cameramapping.domain.repository;

import com.police.cameramapping.domain.model.SurveyAssignment;
import com.police.cameramapping.domain.model.enums.SurveyAssignmentStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface SurveyAssignmentRepository extends JpaRepository<SurveyAssignment, Long>, JpaSpecificationExecutor<SurveyAssignment> {
    Page<SurveyAssignment> findBySurveyor_IdAndIsDeletedFalse(Long surveyorId, Pageable pageable);
    List<SurveyAssignment> findBySurveyor_IdAndStatusAndIsDeletedFalse(Long surveyorId, SurveyAssignmentStatus status);
}
