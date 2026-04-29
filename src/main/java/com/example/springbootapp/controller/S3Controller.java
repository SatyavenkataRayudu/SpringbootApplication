package com.example.springbootapp.controller;

import com.example.springbootapp.service.S3Service;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/s3")
public class S3Controller {

    private final S3Service s3Service;

    public S3Controller(S3Service s3Service) {
        this.s3Service = s3Service;
    }

    /**
     * Check S3 bucket accessibility
     * GET /api/s3/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> checkS3Health() {
        Map<String, Object> response = new HashMap<>();
        boolean accessible = s3Service.isBucketAccessible();
        
        response.put("bucket", s3Service.getBucketName());
        response.put("accessible", accessible);
        response.put("status", accessible ? "UP" : "DOWN");
        
        return ResponseEntity.ok(response);
    }

    /**
     * Upload text to S3
     * POST /api/s3/upload
     * Body: { "key": "filename.txt", "content": "file content" }
     */
    @PostMapping("/upload")
    public ResponseEntity<Map<String, String>> uploadFile(@RequestBody Map<String, String> request) {
        try {
            String key = request.get("key");
            String content = request.get("content");
            
            if (key == null || content == null) {
                Map<String, String> error = new HashMap<>();
                error.put("error", "Both 'key' and 'content' are required");
                return ResponseEntity.badRequest().body(error);
            }
            
            String result = s3Service.uploadText(key, content);
            
            Map<String, String> response = new HashMap<>();
            response.put("message", result);
            response.put("key", key);
            response.put("bucket", s3Service.getBucketName());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, String> error = new HashMap<>();
            error.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
        }
    }

    /**
     * Download file from S3
     * GET /api/s3/download/{key}
     */
    @GetMapping("/download/{key}")
    public ResponseEntity<Map<String, String>> downloadFile(@PathVariable String key) {
        try {
            String content = s3Service.downloadText(key);
            
            Map<String, String> response = new HashMap<>();
            response.put("key", key);
            response.put("content", content);
            response.put("bucket", s3Service.getBucketName());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, String> error = new HashMap<>();
            error.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(error);
        }
    }

    /**
     * List all files in S3 bucket
     * GET /api/s3/list
     */
    @GetMapping("/list")
    public ResponseEntity<Map<String, Object>> listFiles() {
        try {
            List<String> files = s3Service.listObjects();
            
            Map<String, Object> response = new HashMap<>();
            response.put("bucket", s3Service.getBucketName());
            response.put("count", files.size());
            response.put("files", files);
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, Object> error = new HashMap<>();
            error.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
        }
    }

    /**
     * Delete file from S3
     * DELETE /api/s3/delete/{key}
     */
    @DeleteMapping("/delete/{key}")
    public ResponseEntity<Map<String, String>> deleteFile(@PathVariable String key) {
        try {
            String result = s3Service.deleteObject(key);
            
            Map<String, String> response = new HashMap<>();
            response.put("message", result);
            response.put("key", key);
            response.put("bucket", s3Service.getBucketName());
            
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            Map<String, String> error = new HashMap<>();
            error.put("error", e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
        }
    }
}
