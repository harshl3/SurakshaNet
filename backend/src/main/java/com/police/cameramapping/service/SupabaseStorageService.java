package com.police.cameramapping.service;

import com.police.cameramapping.common.exception.BadRequestException;
import jakarta.annotation.PostConstruct;
import lombok.Getter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.time.Duration;
import java.util.UUID;

@Slf4j
@Service
public class SupabaseStorageService {

    @Value("${app.supabase.url:}")
    private String rawSupabaseUrl;

    @Value("${app.supabase.key:}")
    private String rawSupabaseKey;

    @Value("${app.supabase.bucket:camera-media}")
    private String rawBucketName;

    private String supabaseUrl;
    private String supabaseKey;
    private String bucketName;

    private final Path localFallbackDir = Paths.get("uploads", "cameras").toAbsolutePath().normalize();
    private HttpClient httpClient;

    @Getter
    public static class StorageUploadResult {
        private final String url;
        private final String fileName;
        private final String storageType; // "supabase" or "local"

        public StorageUploadResult(String url, String fileName, String storageType) {
            this.url = url;
            this.fileName = fileName;
            this.storageType = storageType;
        }
    }

    @PostConstruct
    public void init() {
        // Initialize local fallback directory
        try {
            Files.createDirectories(localFallbackDir);
        } catch (IOException e) {
            log.error("Failed to initialize local fallback upload directory: {}", e.getMessage());
        }

        // Clean & sanitize config values
        this.supabaseUrl = (rawSupabaseUrl != null) ? rawSupabaseUrl.trim().replaceAll("/+$", "") : "";
        this.supabaseKey = (rawSupabaseKey != null) ? rawSupabaseKey.trim() : "";
        this.bucketName = (rawBucketName != null && !rawBucketName.isBlank()) ? rawBucketName.trim() : "camera-media";

        this.httpClient = HttpClient.newBuilder()
                .version(HttpClient.Version.HTTP_1_1)
                .connectTimeout(Duration.ofSeconds(10))
                .build();

        if (isConfigured()) {
            log.info("Supabase Storage integration enabled: target bucket '{}' at {}", bucketName, supabaseUrl);
            ensureBucketExists();
        } else {
            log.warn("Supabase Storage credentials not configured or using placeholders. Uploads will use resilient local storage fallback.");
        }
    }

    /**
     * Checks if valid Supabase credentials have been supplied.
     */
    public boolean isConfigured() {
        return supabaseUrl != null && !supabaseUrl.isBlank() 
                && !supabaseUrl.contains("...") 
                && !supabaseUrl.contains("your-project-id") 
                && (supabaseUrl.startsWith("http://") || supabaseUrl.startsWith("https://"))
                && supabaseKey != null && !supabaseKey.isBlank() 
                && !supabaseKey.contains("...")
                && supabaseKey.length() > 15;
    }

    /**
     * Ensures the configured bucket exists on Supabase Storage. If missing, attempts creation.
     */
    private void ensureBucketExists() {
        try {
            URI bucketUri = URI.create(supabaseUrl + "/storage/v1/bucket/" + bucketName);
            HttpRequest checkRequest = HttpRequest.newBuilder()
                    .uri(bucketUri)
                    .timeout(Duration.ofSeconds(6))
                    .header("Authorization", "Bearer " + supabaseKey)
                    .header("apikey", supabaseKey)
                    .GET()
                    .build();

            HttpResponse<String> checkResponse = httpClient.send(checkRequest, HttpResponse.BodyHandlers.ofString());

            if (checkResponse.statusCode() == 200) {
                log.info("Verified Supabase bucket '{}' is accessible.", bucketName);
                return;
            }

            if (checkResponse.statusCode() == 404) {
                log.info("Supabase bucket '{}' does not exist. Creating as public bucket...", bucketName);
                String createPayload = String.format("{\"id\":\"%s\",\"name\":\"%s\",\"public\":true}", bucketName, bucketName);
                HttpRequest createRequest = HttpRequest.newBuilder()
                        .uri(URI.create(supabaseUrl + "/storage/v1/bucket"))
                        .timeout(Duration.ofSeconds(8))
                        .header("Authorization", "Bearer " + supabaseKey)
                        .header("apikey", supabaseKey)
                        .header("Content-Type", "application/json")
                        .POST(HttpRequest.BodyPublishers.ofString(createPayload, StandardCharsets.UTF_8))
                        .build();

                HttpResponse<String> createResponse = httpClient.send(createRequest, HttpResponse.BodyHandlers.ofString());
                if (createResponse.statusCode() >= 200 && createResponse.statusCode() < 300) {
                    log.info("Successfully created public Supabase bucket '{}'", bucketName);
                } else {
                    log.warn("Notice: bucket creation returned HTTP {}: {}", createResponse.statusCode(), createResponse.body());
                }
            } else {
                log.info("Supabase bucket check status: HTTP {} (proceeding with uploads)", checkResponse.statusCode());
            }
        } catch (Exception e) {
            log.warn("Unable to verify/create Supabase bucket '{}' on startup (will attempt uploads regardless): {}", bucketName, e.getMessage());
        }
    }

    /**
     * Uploads a camera image to Supabase Storage, with fallback to local filesystem.
     *
     * @param file The multipart image file
     * @return StorageUploadResult containing public access URL and metadata
     */
    public StorageUploadResult uploadCameraImage(MultipartFile file) {
        if (file.isEmpty()) {
            throw new BadRequestException("Uploaded camera file is empty");
        }

        String originalFilename = file.getOriginalFilename();
        String extension = ".jpg";
        if (originalFilename != null && originalFilename.contains(".")) {
            extension = originalFilename.substring(originalFilename.lastIndexOf(".")).toLowerCase();
        }

        if (!extension.matches("\\.(jpg|jpeg|png|webp|gif)$")) {
            throw new BadRequestException("Only image files (.jpg, .jpeg, .png, .webp, .gif) are supported");
        }

        String contentType = file.getContentType();
        if (contentType == null || !contentType.startsWith("image/")) {
            contentType = switch (extension) {
                case ".png" -> "image/png";
                case ".webp" -> "image/webp";
                case ".gif" -> "image/gif";
                default -> "image/jpeg";
            };
        }

        // Generate unique camera image key: cam_<timestamp>_<uuid>.<ext>
        String uniqueFileName = "cam_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 8) + extension;

        byte[] fileBytes;
        try {
            fileBytes = file.getBytes();
        } catch (IOException e) {
            throw new RuntimeException("Failed to read image bytes: " + e.getMessage(), e);
        }

        // 1. Attempt Supabase Storage Upload if configured
        if (isConfigured()) {
            try {
                URI uploadUri = URI.create(supabaseUrl + "/storage/v1/object/" + bucketName + "/" + uniqueFileName);
                HttpRequest uploadRequest = HttpRequest.newBuilder()
                        .uri(uploadUri)
                        .timeout(Duration.ofSeconds(15))
                        .header("Authorization", "Bearer " + supabaseKey)
                        .header("apikey", supabaseKey)
                        .header("Content-Type", contentType)
                        .header("x-upsert", "true")
                        .POST(HttpRequest.BodyPublishers.ofByteArray(fileBytes))
                        .build();

                HttpResponse<String> response = httpClient.send(uploadRequest, HttpResponse.BodyHandlers.ofString());

                if (response.statusCode() >= 200 && response.statusCode() < 300) {
                    String publicUrl = supabaseUrl + "/storage/v1/object/public/" + bucketName + "/" + uniqueFileName;
                    log.info("Successfully uploaded camera image to Supabase Storage: {}", publicUrl);
                    return new StorageUploadResult(publicUrl, uniqueFileName, "supabase");
                } else {
                    log.warn("Supabase Storage upload returned HTTP {} (falling back to local storage): {}", 
                            response.statusCode(), response.body());
                }
            } catch (Exception e) {
                log.warn("Supabase Storage upload failed with error (falling back to local storage): {}", e.getMessage());
            }
        }

        // 2. Resilient Local Storage Fallback
        try {
            Path destination = localFallbackDir.resolve(uniqueFileName);
            Files.write(destination, fileBytes);
            String localUrl = "/api/v1/media/" + uniqueFileName;
            log.info("Stored camera image in local storage fallback: {}", localUrl);
            return new StorageUploadResult(localUrl, uniqueFileName, "local");
        } catch (IOException e) {
            throw new RuntimeException("Failed to save media file to fallback storage: " + e.getMessage(), e);
        }
    }
}
