# ---------- Stage 1: Compile (Maven + JDK, isolated) ----------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn -B clean package -DskipTests

# ---------- Stage 2: Runtime (Debian 13) ----------
FROM debian:13-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /build/target/compvalidator-app-jar-with-dependencies.jar /app/app.jar

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
