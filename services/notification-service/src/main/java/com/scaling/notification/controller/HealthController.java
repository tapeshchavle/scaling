package com.scaling.notification.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/notifications")
public class HealthController {

    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        return ResponseEntity.ok(Map.of(
                "service", "notification-service",
                "status", "UP",
                "timestamp", Instant.now().toString(),
                "channels", Map.of(
                        "email", "configured",
                        "sms", "configured",
                        "push", "configured"
                )
        ));
    }
}
