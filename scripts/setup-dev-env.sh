#!/bin/bash

# Script to set up a personal development environment in AWS

set -e

# Configuration
ENV_NAME=$1
AWS_REGION=${2:-us-east-1}
CLUSTER_NAME="dev-${ENV_NAME}"
NAMESPACE="${ENV_NAME}"

# Validate input
if [ -z "$ENV_NAME" ]; then
    echo "Usage: $0 <environment-name> [aws-region]"
    echo "Example: $0 john-feature us-east-1"
    exit 1
fi

echo "Setting up personal environment: $ENV_NAME in $AWS_REGION"

# Create namespace
echo "Creating namespace..."
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
EOF

# Set resource quotas
echo "Setting resource quotas..."
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${ENV_NAME}-quota
  namespace: ${NAMESPACE}
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
EOF

# Create service account
echo "Creating service account..."
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${ENV_NAME}-sa
  namespace: ${NAMESPACE}
EOF

# Set up monitoring
echo "Setting up monitoring..."
cat << EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: ${ENV_NAME}-monitor
  namespace: ${NAMESPACE}
spec:
  selector:
    matchLabels:
      environment: ${ENV_NAME}
  podMetricsEndpoints:
  - port: metrics
EOF

# Create development database
echo "Creating development database..."
aws rds create-db-instance \
    --db-instance-identifier ${ENV_NAME}-db \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --master-username ${ENV_NAME} \
    --master-user-password $(openssl rand -base64 32) \
    --allocated-storage 20 \
    --tags Key=Environment,Value=${ENV_NAME}

# Set up environment-specific ingress
echo "Setting up ingress..."
cat << EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${ENV_NAME}-ingress
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: ${ENV_NAME}.dev.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${ENV_NAME}-service
            port:
              number: 80
EOF

# Create Grafana dashboard
echo "Creating Grafana dashboard..."
cat << EOF > /tmp/${ENV_NAME}-dashboard.json
{
  "dashboard": {
    "title": "${ENV_NAME} Environment Dashboard",
    "panels": [
      {
        "title": "Pod Status",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "title": "Resource Usage",
        "type": "graph",
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      }
    ]
  }
}
EOF

# Print environment information
echo "Environment setup complete!"
echo "-----------------------------"
echo "Environment: ${ENV_NAME}"
echo "Namespace: ${NAMESPACE}"
echo "Ingress URL: https://${ENV_NAME}.dev.example.com"
echo "Resource Quotas:"
echo "  - CPU: 4 cores (max 8)"
echo "  - Memory: 8Gi (max 16Gi)"
echo "  - Pods: 20 max"
echo ""
echo "Next steps:"
echo "1. Wait for RDS instance to be ready (~5-10 minutes)"
echo "2. Configure your kubectl context: kubectl config use-context ${CLUSTER_NAME}"
echo "3. Access your namespace: kubectl ns ${NAMESPACE}"
echo "4. View your Grafana dashboard at: https://grafana.example.com/d/${ENV_NAME}"