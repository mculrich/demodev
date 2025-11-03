# PowerShell script to set up a personal development environment in AWS

param(
    [Parameter(Mandatory=$true)]
    [string]$EnvName,
    
    [Parameter(Mandatory=$false)]
    [string]$AwsRegion = "us-east-1"
)

# Configuration
$CLUSTER_NAME = "dev-${EnvName}"
$NAMESPACE = $EnvName

# Validate AWS CLI installation and authentication
try {
    Write-Host "Checking AWS CLI configuration..."
    aws sts get-caller-identity
} catch {
    Write-Host "Error: AWS CLI is not installed or not configured properly"
    Write-Host "Please install AWS CLI and configure your credentials"
    exit 1
}

# Validate kubectl installation
try {
    Write-Host "Checking kubectl installation..."
    kubectl version --client
} catch {
    Write-Host "Error: kubectl is not installed"
    Write-Host "Please install kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/"
    exit 1
}

Write-Host "Setting up personal environment: $EnvName in $AwsRegion"

# Create namespace
Write-Host "Creating namespace..."
@"
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
"@ | kubectl apply -f -

# Set resource quotas
Write-Host "Setting resource quotas..."
@"
apiVersion: v1
kind: ResourceQuota
metadata:
  name: ${EnvName}-quota
  namespace: ${NAMESPACE}
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
"@ | kubectl apply -f -

# Create service account
Write-Host "Creating service account..."
@"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${EnvName}-sa
  namespace: ${NAMESPACE}
"@ | kubectl apply -f -

# Set up monitoring
Write-Host "Setting up monitoring..."
@"
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: ${EnvName}-monitor
  namespace: ${NAMESPACE}
spec:
  selector:
    matchLabels:
      environment: ${EnvName}
  podMetricsEndpoints:
  - port: metrics
"@ | kubectl apply -f -

# Create development database
Write-Host "Creating development database..."
$password = [System.Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(24))
aws rds create-db-instance `
    --db-instance-identifier "${EnvName}-db" `
    --db-instance-class db.t3.micro `
    --engine postgres `
    --master-username $EnvName `
    --master-user-password $password `
    --allocated-storage 20 `
    --tags Key=Environment,Value=$EnvName

# Set up environment-specific ingress
Write-Host "Setting up ingress..."
@"
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${EnvName}-ingress
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: ${EnvName}.dev.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${EnvName}-service
            port:
              number: 80
"@ | kubectl apply -f -

# Create Grafana dashboard configuration
$dashboardConfig = @{
    dashboard = @{
        title = "${EnvName} Environment Dashboard"
        panels = @(
            @{
                title = "Pod Status"
                type = "graph"
                gridPos = @{
                    h = 8
                    w = 12
                    x = 0
                    y = 0
                }
            },
            @{
                title = "Resource Usage"
                type = "graph"
                gridPos = @{
                    h = 8
                    w = 12
                    x = 12
                    y = 0
                }
            }
        )
    }
} | ConvertTo-Json -Depth 10

$dashboardConfig | Out-File -FilePath "$env:TEMP\${EnvName}-dashboard.json"

# Print environment information
Write-Host "`nEnvironment setup complete!"
Write-Host "-----------------------------"
Write-Host "Environment: ${EnvName}"
Write-Host "Namespace: ${NAMESPACE}"
Write-Host "Ingress URL: https://${EnvName}.dev.example.com"
Write-Host "Resource Quotas:"
Write-Host "  - CPU: 4 cores (max 8)"
Write-Host "  - Memory: 8Gi (max 16Gi)"
Write-Host "  - Pods: 20 max"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Wait for RDS instance to be ready (~5-10 minutes)"
Write-Host "2. Configure your kubectl context: kubectl config use-context ${CLUSTER_NAME}"
Write-Host "3. Access your namespace: kubectl ns ${NAMESPACE}"
Write-Host "4. View your Grafana dashboard at: https://grafana.example.com/d/${EnvName}"

# Save database credentials securely
Write-Host "`nDatabase credentials have been created:"
Write-Host "Username: $EnvName"
Write-Host "Password has been generated and will be stored in AWS Secrets Manager"

# Store password in AWS Secrets Manager
aws secretsmanager create-secret --name "dev/${EnvName}/db-credentials" --secret-string "{`"username`":`"${EnvName}`",`"password`":`"${password}`"}"