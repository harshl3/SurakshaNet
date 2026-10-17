package com.police.cameramapping.service;

import com.police.cameramapping.domain.model.InvestigationCase;
import com.police.cameramapping.dto.investigation.CaseCameraAttachRequest;
import com.police.cameramapping.dto.investigation.InvestigationCaseRequest;
import com.police.cameramapping.dto.investigation.InvestigationCaseResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

public interface InvestigationService {
    InvestigationCaseResponse createCase(InvestigationCaseRequest request, String currentUsername);
    InvestigationCaseResponse getCaseById(Long id);
    InvestigationCaseResponse getCaseByNumber(String caseNumber);
    Page<InvestigationCase> getAllCases(Pageable pageable);
    Page<InvestigationCaseResponse> getAllCaseResponses(Pageable pageable);
    InvestigationCaseResponse attachCameraToCase(Long caseId, CaseCameraAttachRequest request, String currentUsername);
    void deleteCase(Long id, String currentUsername);
}
