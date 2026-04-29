package com.example.springbootapp.controller;

import com.example.springbootapp.service.S3Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.HashMap;
import java.util.Map;

@RestController
public class HealthController {

    @Autowired(required = false)
    private S3Service s3Service;

    @GetMapping("/")
    public Map<String, Object> home() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("message", "Spring Boot Application is running!");
        response.put("version", "1.0.0");
        
        // Add S3 status if available
        if (s3Service != null) {
            response.put("s3_enabled", true);
            response.put("s3_bucket", s3Service.getBucketName());
            response.put("s3_accessible", s3Service.isBucketAccessible());
        } else {
            response.put("s3_enabled", false);
        }
        
        return response;
    }

    @GetMapping("/api/info")
    public Map<String, String> info() {
        Map<String, String> response = new HashMap<>();
        response.put("application", "Spring Boot CI/CD Demo");
        response.put("description", "Deployed via Jenkins to AWS EKS");
        response.put("features", "REST API, S3 Integration, Health Checks, Metrics");
        return response;
    }
}
