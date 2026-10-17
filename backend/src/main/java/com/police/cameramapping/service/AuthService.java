package com.police.cameramapping.service;

import com.police.cameramapping.dto.auth.JwtResponse;
import com.police.cameramapping.dto.auth.LoginRequest;
import com.police.cameramapping.dto.auth.RefreshTokenRequest;
import com.police.cameramapping.dto.auth.RegisterRequest;

public interface AuthService {
    JwtResponse login(LoginRequest request);
    JwtResponse register(RegisterRequest request);
    JwtResponse refreshToken(RefreshTokenRequest request);
}
