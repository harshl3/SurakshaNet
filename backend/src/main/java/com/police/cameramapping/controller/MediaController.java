package com.police.cameramapping.controller;

import com.police.cameramapping.common.dto.ApiResponse;
import com.police.cameramapping.service.SupabaseStorageService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.net.MalformedURLException;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/media")
@RequiredArgsConstructor
@Tag(name = "Media Storage Module", description = "Upload and serve CCTV camera photos and site images via Supabase Storage")
public class MediaController {

    private final SupabaseStorageService supabaseStorageService;
    private final Path uploadDir = Paths.get("uploads", "cameras").toAbsolutePath().normalize();

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Upload camera photo / live camera snapshot to Supabase Storage")
    public ResponseEntity<ApiResponse<Map<String, String>>> uploadMedia(@RequestParam("file") MultipartFile file) {
        SupabaseStorageService.StorageUploadResult result = supabaseStorageService.uploadCameraImage(file);

        Map<String, String> responseData = new HashMap<>();
        responseData.put("url", result.getUrl());
        responseData.put("fileName", result.getFileName());
        responseData.put("storage", result.getStorageType());

        String message = "supabase".equalsIgnoreCase(result.getStorageType())
                ? "Camera image uploaded to Supabase Storage successfully"
                : "Camera image saved to local storage fallback";

        return ResponseEntity.ok(ApiResponse.success(responseData, message));
    }

    @GetMapping("/{fileName:.+}")
    @Operation(summary = "Serve uploaded camera photo from local fallback storage")
    public ResponseEntity<Resource> getMedia(@PathVariable String fileName) {
        try {
            Path filePath = uploadDir.resolve(fileName).normalize();
            Resource resource = new UrlResource(filePath.toUri());

            if (!resource.exists() || !resource.isReadable()) {
                return ResponseEntity.notFound().build();
            }

            String contentType = "image/jpeg";
            if (fileName.toLowerCase().endsWith(".png")) {
                contentType = "image/png";
            } else if (fileName.toLowerCase().endsWith(".webp")) {
                contentType = "image/webp";
            } else if (fileName.toLowerCase().endsWith(".gif")) {
                contentType = "image/gif";
            }

            return ResponseEntity.ok()
                    .contentType(MediaType.parseMediaType(contentType))
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + resource.getFilename() + "\"")
                    .body(resource);
        } catch (MalformedURLException e) {
            return ResponseEntity.badRequest().build();
        }
    }
}

