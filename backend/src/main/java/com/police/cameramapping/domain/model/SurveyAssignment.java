package com.police.cameramapping.domain.model;

import com.police.cameramapping.domain.model.enums.SurveyAssignmentStatus;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;

@Entity
@Table(name = "survey_assignments")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SurveyAssignment extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "surveyor_id", nullable = false)
    private User surveyor;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "police_station_id", nullable = false)
    private PoliceStation policeStation;

    @Column(name = "target_area", nullable = false, length = 150)
    private String targetArea;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "assigned_by_id", nullable = false)
    private User assignedBy;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private SurveyAssignmentStatus status = SurveyAssignmentStatus.PENDING;

    @Column(name = "due_date")
    private LocalDate dueDate;

    @Column(name = "completion_percentage")
    private Double completionPercentage = 0.0;

    @Column(columnDefinition = "TEXT")
    private String remarks;
}
