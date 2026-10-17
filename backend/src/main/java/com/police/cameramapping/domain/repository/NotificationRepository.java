package com.police.cameramapping.domain.repository;

import com.police.cameramapping.domain.model.Notification;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    Page<Notification> findByRecipient_IdOrderByCreatedAtDesc(Long userId, Pageable pageable);
    List<Notification> findByRecipient_IdAndIsReadFalseOrderByCreatedAtDesc(Long userId);
    long countByRecipient_IdAndIsReadFalse(Long userId);
}
