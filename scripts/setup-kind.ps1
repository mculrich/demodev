# PowerShell script to create a local Kubernetes cluster using kind and deploy demo manifests
param(
  [string]$ClusterName = "dev-kind-cluster"
)

# Check for kind
if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
  Write-Host "kind not found. Installing via scoop if available..."
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    scoop install kind
  } else {
    Write-Host "Please install kind manually: https://kind.sigs.k8s.io/docs/user/quick-start/"
    exit 1
  }
}

# Create cluster
Write-Host "Creating kind cluster: $ClusterName"
kind create cluster --name $ClusterName

# Load local manifests (if any)
if (Test-Path .\kubernetes) {
  Write-Host "Applying Kubernetes manifests from ./kubernetes"
  try {
    kubectl apply -k ./kubernetes
  } catch {
    kubectl apply -R -f ./kubernetes
  }
}

Write-Host "Kind cluster created. Use: kubectl cluster-info --context kind-$ClusterName"
