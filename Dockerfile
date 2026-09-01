# ---------- Stage 1: Compile (Maven + JDK 17) ----------
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /build

COPY pom.xml .
COPY src ./src

RUN mvn -B clean package -DskipTests


# ---------- Stage 2: Runtime (Java 17) ----------
FROM eclipse-temurin:17-jre

WORKDIR /app

COPY --from=build /build/target/compvalidator-app-1.2.3-jar-with-dependencies.jar /app/app.jar

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
