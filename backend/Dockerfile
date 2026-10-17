# ==============================================================================
# Multi-stage Dockerfile for Police Camera Mapping System (Spring Boot 3 + Java 21)
# ==============================================================================

# Stage 1: Build stage with pre-installed Maven & Java 21
FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /workspace/app

# Copy pom.xml and source code to build production jar
COPY pom.xml ./
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: Minimal, secure runtime container
FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

# Run as non-root user for security
RUN groupadd -r spring && useradd -r -g spring spring
USER spring:spring

# Copy built jar from builder stage
COPY --from=builder --chown=spring:spring /workspace/app/target/*.jar app.jar

# Render injects PORT dynamically (defaults to 8088 if local)
ENV PORT=8088
EXPOSE 8088

# Launch Spring Boot with container memory optimization
ENTRYPOINT ["sh", "-c", "java -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Dserver.port=${PORT} -jar app.jar"]
