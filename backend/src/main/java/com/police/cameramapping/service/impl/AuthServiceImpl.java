package com.police.cameramapping.service.impl;

import com.police.cameramapping.common.exception.BadRequestException;
import com.police.cameramapping.common.exception.ResourceNotFoundException;
import com.police.cameramapping.domain.model.PoliceStation;
import com.police.cameramapping.domain.model.Role;
import com.police.cameramapping.domain.model.User;
import com.police.cameramapping.domain.repository.PoliceStationRepository;
import com.police.cameramapping.domain.repository.RoleRepository;
import com.police.cameramapping.domain.repository.UserRepository;
import com.police.cameramapping.dto.auth.JwtResponse;
import com.police.cameramapping.dto.auth.LoginRequest;
import com.police.cameramapping.dto.auth.RefreshTokenRequest;
import com.police.cameramapping.dto.auth.RegisterRequest;
import com.police.cameramapping.security.JwtUtils;
import com.police.cameramapping.security.UserDetailsImpl;
import com.police.cameramapping.service.AuthService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthServiceImpl implements AuthService {

    private final AuthenticationManager authenticationManager;
    private final UserRepository userRepository;
    private final RoleRepository roleRepository;
    private final PoliceStationRepository policeStationRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;

    @Override
    @Transactional
    public JwtResponse login(LoginRequest request) {
        Authentication authentication = authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(request.getUsername(), request.getPassword()));

        SecurityContextHolder.getContext().setAuthentication(authentication);
        String jwt = jwtUtils.generateJwtToken(authentication);
        UserDetailsImpl userDetails = (UserDetailsImpl) authentication.getPrincipal();
        
        User user = userRepository.findById(userDetails.getId())
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userDetails.getId()));

        String refreshToken = jwtUtils.generateRefreshToken(user.getUsername());

        String roleName = "ROLE_POLICE_OFFICER";
        if (user.getRole() != null && user.getRole().getName() != null) {
            roleName = user.getRole().getName().name();
        }

        return JwtResponse.builder()
                .token(jwt)
                .refreshToken(refreshToken)
                .id(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .fullName(user.getFullName())
                .role(roleName)
                .policeStationId(user.getPoliceStation() != null ? user.getPoliceStation().getId() : null)
                .policeStationName(user.getPoliceStation() != null ? user.getPoliceStation().getStationName() : null)
                .build();
    }

    @Override
    @Transactional
    public JwtResponse register(RegisterRequest request) {
        if (userRepository.existsByUsername(request.getUsername())) {
            throw new BadRequestException("Username '" + request.getUsername() + "' is already taken!");
        }

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new BadRequestException("Email '" + request.getEmail() + "' is already registered!");
        }

        Role role = roleRepository.findByName(request.getRole())
                .orElseThrow(() -> new ResourceNotFoundException("Role", "name", request.getRole()));

        PoliceStation station = null;
        if (request.getPoliceStationId() != null) {
            station = policeStationRepository.findById(request.getPoliceStationId())
                    .orElseThrow(() -> new ResourceNotFoundException("PoliceStation", "id", request.getPoliceStationId()));
        }

        User user = User.builder()
                .username(request.getUsername())
                .email(request.getEmail())
                .password(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName())
                .phone(request.getPhone())
                .badgeNumber(request.getBadgeNumber())
                .role(role)
                .policeStation(station)
                .isActive(true)
                .build();

        userRepository.save(user);

        // Auto login after registration
        return login(new LoginRequest() {{
            setUsername(request.getUsername());
            setPassword(request.getPassword());
        }});
    }

    @Override
    @Transactional(readOnly = true)
    public JwtResponse refreshToken(RefreshTokenRequest request) {
        String refreshToken = request.getRefreshToken();
        if (!jwtUtils.validateJwtToken(refreshToken)) {
            throw new BadRequestException("Invalid or expired refresh token");
        }

        String username = jwtUtils.getUserNameFromJwtToken(refreshToken);
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("User", "username", username));

        String newToken = jwtUtils.generateTokenFromUsername(username);

        return JwtResponse.builder()
                .token(newToken)
                .refreshToken(refreshToken)
                .id(user.getId())
                .username(user.getUsername())
                .email(user.getEmail())
                .fullName(user.getFullName())
                .role(user.getRole().getName().name())
                .policeStationId(user.getPoliceStation() != null ? user.getPoliceStation().getId() : null)
                .policeStationName(user.getPoliceStation() != null ? user.getPoliceStation().getStationName() : null)
                .build();
    }
}
