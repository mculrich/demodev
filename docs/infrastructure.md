# Infrastructure Setup Guide

This document outlines the infrastructure setup process for our AWS-based Kubernetes platform.

## Architecture Overview

Our infrastructure follows AWS best practices and implements a highly available, secure, and scalable architecture:

- Multi-AZ VPC with public and private subnets
- EKS cluster for container orchestration
- RDS instances for persistent data storage
- Prometheus and Grafana for monitoring
- AWS Load Balancers for traffic distribution
- WAF for web application security

## Network Architecture

```
                                     │
                                     ▼
                              ┌──────────────┐
                              │    Route53   │
                              └──────────────┘
                                     │
                                     ▼
                              ┌──────────────┐
                              │     ALB      │
                              └──────────────┘
                                     │
                     ┌───────────────┴───────────────┐
                     ▼                               ▼
              ┌──────────────┐               ┌──────────────┐
              │  Public Sub  │               │  Public Sub  │
              └──────────────┘               └──────────────┘
                     │                               │
                     ▼                               ▼
              ┌──────────────┐               ┌──────────────┐
              │ Private Sub  │               │ Private Sub  │
              └──────────────┘               └──────────────┘
                     │                               │
                     ▼                               ▼
              ┌──────────────┐               ┌──────────────┐
              │  EKS Nodes   │               │  EKS Nodes   │
              └──────────────┘               └──────────────┘
                     │                               │
                     └───────────────┬───────────────┘
                                     ▼
                              ┌──────────────┐
                              │     RDS      │
                              └──────────────┘
```

## Security Measures

1. Network Security
   - VPC with private subnets
   - Security groups with least privilege
   - Network ACLs for subnet protection
   - VPC Flow Logs enabled

2. Access Control
   - IAM roles with minimal permissions
   - RBAC for Kubernetes access
   - AWS KMS for encryption
   - Secrets management

3. Compliance
   - Regular security scans
   - Automated compliance checks
   - Audit logging enabled

## Deployment Process

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Plan changes:
   ```bash
   terraform plan -var-file=environments/dev.tfvars
   ```

3. Apply infrastructure:
   ```bash
   terraform apply -var-file=environments/dev.tfvars
   ```

4. Configure kubectl:
   ```bash
   aws eks update-kubeconfig --name dev-cluster --region us-east-1
   ```

5. Deploy monitoring stack:
   ```bash
   kubectl apply -f kubernetes/monitoring.yaml
   ```

## Monitoring Setup

1. Access Grafana:
   - URL: https://grafana.example.com
   - Default credentials in AWS Secrets Manager

2. Key Dashboards:
   - Cluster Overview
   - Node Metrics
   - Application Performance
   - Cost Analysis

3. Alert Configuration:
   - CPU/Memory thresholds
   - Error rate monitoring
   - Latency alerts
   - Disk usage warnings

## Backup and Recovery

1. Database Backups:
   - Automated daily snapshots
   - Point-in-time recovery enabled
   - Cross-region replication

2. EKS Backup:
   - etcd snapshots
   - Velero for cluster backup
   - S3 bucket storage

## Cost Optimization

1. Resource Management:
   - Auto-scaling policies
   - Spot instances utilization
   - Right-sizing recommendations

2. Monitoring:
   - Cost allocation tags
   - Budget alerts
   - Usage analytics

## Troubleshooting Guide

1. Common Issues:
   - Pod scheduling failures
   - Network connectivity
   - Resource constraints
   - Authentication errors

2. Debug Commands:
   ```bash
   # Check pod status
   kubectl get pods -A
   
   # View pod logs
   kubectl logs <pod-name>
   
   # Describe resource
   kubectl describe <resource-type> <resource-name>
   ```

3. Support Process:
   - Escalation path
   - On-call rotation
   - Incident documentation

## Maintenance Procedures

1. Regular Updates:
   - Security patches
   - Kubernetes versions
   - Dependencies
   - AWS provider updates

2. Health Checks:
   - Daily automated tests
   - Performance monitoring
   - Security scans
   - Compliance audits