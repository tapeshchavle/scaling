FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
COPY services/food-core/pom.xml services/food-core/pom.xml
COPY services/notification-service/pom.xml services/notification-service/pom.xml
RUN mvn dependency:go-offline -pl services/notification-service -am
COPY services/notification-service/src services/notification-service/src
RUN mvn clean package -DskipTests -pl services/notification-service -am

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
WORKDIR /app
COPY --from=builder /build/services/notification-service/target/*.jar app.jar
EXPOSE 8082
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8082/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
