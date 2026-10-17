package com.police.cameramapping.domain.repository;

import com.police.cameramapping.domain.model.Role;
import com.police.cameramapping.domain.model.enums.RoleEnum;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface RoleRepository extends JpaRepository<Role, Long> {
    Optional<Role> findByName(RoleEnum name);
}
