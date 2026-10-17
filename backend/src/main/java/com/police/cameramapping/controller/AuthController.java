package com.police.cameramapping.controller;

import com.police.cameramapping.common.dto.ApiResponse;
import com.police.cameramapping.dto.auth.JwtResponse;
import com.police.cameramapping.dto.auth.LoginRequest;
import com.police.cameramapping.dto.auth.RefreshTokenRequest;
import com.police.cameramapping.dto.auth.RegisterRequest;
import com.police.cameramapping.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
@Tag(name = "Authentication Module", description = "Endpoints for User Login, Registration, and JWT Refresh")
public class AuthController {

    private final AuthService authService;

    @PostMapping("/login")
    @Operation(summary = "Authenticate user and return JWT access token")
    public ResponseEntity<ApiResponse<JwtResponse>> login(@Valid @RequestBody LoginRequest request) {
        JwtResponse jwtResponse = authService.login(request);
        return ResponseEntity.ok(ApiResponse.success(jwtResponse, "User authenticated successfully"));
    }

    @PostMapping("/register")
    @Operation(summary = "Register new Police Officer or Survey Person user")
    public ResponseEntity<ApiResponse<JwtResponse>> register(@Valid @RequestBody RegisterRequest request) {
        JwtResponse jwtResponse = authService.register(request);
        return ResponseEntity.ok(ApiResponse.success(jwtResponse, "User registered successfully"));
    }

    @PostMapping("/refresh")
    @Operation(summary = "Refresh expired JWT access token")
    public ResponseEntity<ApiResponse<JwtResponse>> refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        JwtResponse jwtResponse = authService.refreshToken(request);
        return ResponseEntity.ok(ApiResponse.success(jwtResponse, "Token refreshed successfully"));
    }
}
