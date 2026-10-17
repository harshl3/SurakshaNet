package com.police.cameramapping.config;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;

import javax.sql.DataSource;
import java.net.URI;
import java.sql.Connection;
import java.sql.Statement;

/**
 * Robust DataSource configuration supporting:
 * 1. Standard Spring Boot properties (spring.datasource.url, username, password)
 * 2. Cloud provider DATABASE_URL (Render, Railway, Heroku) in postgres:// or postgresql:// format
 * 3. Automatic PostGIS extension initialization on first boot
 */
@Configuration
public class DataSourceConfig {

    private static final Logger log = LoggerFactory.getLogger(DataSourceConfig.class);

    @Value("${spring.datasource.url:}")
    private String springUrl;

    @Value("${spring.datasource.username:postgres}")
    private String springUsername;

    @Value("${spring.datasource.password:postgres}")
    private String springPassword;

    @Value("${DATABASE_URL:}")
    private String rawDatabaseUrl;

    @Bean
    @Primary
    public DataSource dataSource() {
        HikariConfig config = new HikariConfig();
        config.setDriverClassName("org.postgresql.Driver");

        String dbUrl = resolveJdbcUrl();
        String user = resolveUsername();
        String pass = resolvePassword();

        config.setJdbcUrl(dbUrl);
        if (user != null && !user.isBlank()) {
            config.setUsername(user);
        }
        if (pass != null && !pass.isBlank()) {
            config.setPassword(pass);
        }

        config.setMaximumPoolSize(10);
        config.setMinimumIdle(2);
        config.setConnectionTimeout(30000);
        config.setIdleTimeout(600000);
        config.setMaxLifetime(1800000);

        log.info("Configured PostgreSQL DataSource with URL: {}", sanitizeUrlForLogging(dbUrl));

        HikariDataSource ds = new HikariDataSource(config);

        // Auto-initialize PostGIS extension for spatial mapping
        initializePostGis(ds);

        return ds;
    }

    private String resolveJdbcUrl() {
        // If DATABASE_URL is set (Render / Cloud environment)
        if (rawDatabaseUrl != null && !rawDatabaseUrl.isBlank()) {
            if (rawDatabaseUrl.startsWith("jdbc:")) {
                return rawDatabaseUrl;
            }
            try {
                URI uri = new URI(rawDatabaseUrl);
                int port = uri.getPort() > 0 ? uri.getPort() : 5432;
                return "jdbc:postgresql://" + uri.getHost() + ":" + port + uri.getPath();
            } catch (Exception e) {
                log.warn("Failed to parse DATABASE_URL as URI, using as-is: {}", e.getMessage());
                return rawDatabaseUrl.startsWith("jdbc:") ? rawDatabaseUrl : "jdbc:" + rawDatabaseUrl;
            }
        }

        // Fallback to spring.datasource.url
        if (springUrl != null && !springUrl.isBlank()) {
            return springUrl;
        }

        return "jdbc:postgresql://localhost:5432/cameramapping";
    }

    private String resolveUsername() {
        if (rawDatabaseUrl != null && !rawDatabaseUrl.isBlank() && !rawDatabaseUrl.startsWith("jdbc:")) {
            try {
                URI uri = new URI(rawDatabaseUrl);
                if (uri.getUserInfo() != null) {
                    return uri.getUserInfo().split(":")[0];
                }
            } catch (Exception ignored) {}
        }
        return springUsername;
    }

    private String resolvePassword() {
        if (rawDatabaseUrl != null && !rawDatabaseUrl.isBlank() && !rawDatabaseUrl.startsWith("jdbc:")) {
            try {
                URI uri = new URI(rawDatabaseUrl);
                if (uri.getUserInfo() != null) {
                    String[] parts = uri.getUserInfo().split(":", 2);
                    if (parts.length > 1) {
                        return parts[1];
                    }
                }
            } catch (Exception ignored) {}
        }
        return springPassword;
    }

    private void initializePostGis(DataSource ds) {
        try (Connection conn = ds.getConnection();
             Statement stmt = conn.createStatement()) {
            stmt.execute("CREATE EXTENSION IF NOT EXISTS postgis;");
            log.info("PostGIS extension verified/initialized successfully.");
        } catch (Exception e) {
            log.warn("Notice: PostGIS extension auto-initialization check: {} (If already enabled, this is safe to ignore).", e.getMessage());
        }
    }

    private String sanitizeUrlForLogging(String url) {
        if (url == null) return "null";
        return url.replaceAll(":[^/@]+@", ":***@");
    }
}
