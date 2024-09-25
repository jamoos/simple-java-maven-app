FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY . . 
RUN mvn -DskipTests clean package && mvn test

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
CMD ["java", "-jar", "app.jar"]
