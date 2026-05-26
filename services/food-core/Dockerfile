FROM maven:3.9-eclipse-temurin-21 AS builder
WORKDIR /build
COPY pom.xml .
COPY services/food-core/pom.xml services/food-core/pom.xml
COPY services/notification-service/pom.xml services/notification-service/pom.xml
RUN mvn dependency:go-offline -pl services/food-core -am
COPY services/food-core/src services/food-core/src
RUN mvn clean package -DskipTests -pl services/food-core -am

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
WORKDIR /app
COPY --from=builder /build/services/food-core/target/*.jar app.jar
EXPOSE 8081
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8081/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
