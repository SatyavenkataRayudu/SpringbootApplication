package com.example.springbootapp.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.*;

import java.util.List;
import java.util.stream.Collectors;

@Service
public class S3Service {

    private static final Logger logger = LoggerFactory.getLogger(S3Service.class);

    private final S3Client s3Client;

    @Value("${aws.s3.bucket}")
    private String bucketName;

    public S3Service(S3Client s3Client) {
        this.s3Client = s3Client;
    }

    /**
     * Upload text content to S3
     */
    public String uploadText(String key, String content) {
        try {
            PutObjectRequest putObjectRequest = PutObjectRequest.builder()
                    .bucket(bucketName)
                    .key(key)
                    .build();

            s3Client.putObject(putObjectRequest, RequestBody.fromString(content));
            logger.info("Successfully uploaded {} to S3 bucket {}", key, bucketName);
            return "Successfully uploaded: " + key;
        } catch (S3Exception e) {
            logger.error("Error uploading to S3: {}", e.getMessage());
            throw new RuntimeException("Failed to upload to S3: " + e.getMessage());
        }
    }

    /**
     * Download content from S3
     */
    public String downloadText(String key) {
        try {
            GetObjectRequest getObjectRequest = GetObjectRequest.builder()
                    .bucket(bucketName)
                    .key(key)
                    .build();

            String content = s3Client.getObjectAsBytes(getObjectRequest).asUtf8String();
            logger.info("Successfully downloaded {} from S3 bucket {}", key, bucketName);
            return content;
        } catch (S3Exception e) {
            logger.error("Error downloading from S3: {}", e.getMessage());
            throw new RuntimeException("Failed to download from S3: " + e.getMessage());
        }
    }

    /**
     * List all objects in the bucket
     */
    public List<String> listObjects() {
        try {
            ListObjectsV2Request listRequest = ListObjectsV2Request.builder()
                    .bucket(bucketName)
                    .build();

            ListObjectsV2Response listResponse = s3Client.listObjectsV2(listRequest);
            
            return listResponse.contents().stream()
                    .map(S3Object::key)
                    .collect(Collectors.toList());
        } catch (S3Exception e) {
            logger.error("Error listing S3 objects: {}", e.getMessage());
            throw new RuntimeException("Failed to list S3 objects: " + e.getMessage());
        }
    }

    /**
     * Delete object from S3
     */
    public String deleteObject(String key) {
        try {
            DeleteObjectRequest deleteRequest = DeleteObjectRequest.builder()
                    .bucket(bucketName)
                    .key(key)
                    .build();

            s3Client.deleteObject(deleteRequest);
            logger.info("Successfully deleted {} from S3 bucket {}", key, bucketName);
            return "Successfully deleted: " + key;
        } catch (S3Exception e) {
            logger.error("Error deleting from S3: {}", e.getMessage());
            throw new RuntimeException("Failed to delete from S3: " + e.getMessage());
        }
    }

    /**
     * Check if bucket exists and is accessible
     */
    public boolean isBucketAccessible() {
        try {
            HeadBucketRequest headBucketRequest = HeadBucketRequest.builder()
                    .bucket(bucketName)
                    .build();
            s3Client.headBucket(headBucketRequest);
            return true;
        } catch (S3Exception e) {
            logger.error("Bucket {} is not accessible: {}", bucketName, e.getMessage());
            return false;
        }
    }

    public String getBucketName() {
        return bucketName;
    }
}
