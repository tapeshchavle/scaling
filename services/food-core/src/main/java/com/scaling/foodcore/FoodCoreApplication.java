package com.scaling.foodcore;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;

@SpringBootApplication
@EnableCaching
public class FoodCoreApplication {
    public static void main(String[] args) {
        SpringApplication.run(FoodCoreApplication.class, args);
    }
}
