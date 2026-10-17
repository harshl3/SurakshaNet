package com.police.cameramapping.domain.model;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "case_cameras")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CaseCamera extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "investigation_case_id", nullable = false)
    private InvestigationCase investigationCase;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "camera_id", nullable = false)
    private Camera camera;

    @Column(name = "distance_meters")
    private Double distanceMeters;

    @Column(name = "footage_start_time")
    private LocalDateTime footageStartTime;

    @Column(name = "footage_end_time")
    private LocalDateTime footageEndTime;

    @Column(name = "evidence_notes", columnDefinition = "TEXT")
    private String evidenceNotes;

    @Column(name = "is_key_evidence", nullable = false)
    private boolean isKeyEvidence = false;
}
