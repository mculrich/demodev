<#
Create or update a Kubernetes Secret with local database credentials.

Usage examples:
  # Use defaults (sensible for local dev)
  .\scripts\create-local-secret.ps1

  # Provide custom values
  .\scripts\create-local-secret.ps1 -Namespace demo -Name dev-db-creds -DbHost host.docker.internal -DbPort 5432 -DbName dev_db -DbUser dev -DbPass devpass

Notes:
 - This script is intended for local development only. Do NOT commit real production credentials to git.
 - The script uses kubectl and requires kubectl to be configured to your cluster.
#>

param(
    [string]$Namespace = 'demo',
    [string]$Name = 'dev-db-creds',
    [string]$DbHost = $(if ($env:DB_HOST) { $env:DB_HOST } else { 'host.docker.internal' }),
    [string]$DbPort = $(if ($env:DB_PORT) { $env:DB_PORT } else { '5432' }),
    [string]$DbName = $(if ($env:DB_NAME) { $env:DB_NAME } else { 'dev_db' }),
    [string]$DbUser = $(if ($env:DB_USER) { $env:DB_USER } else { 'dev' }),
    [string]$DbPass = $(if ($env:DB_PASS) { $env:DB_PASS } else { 'devpass' })
)

Write-Host "Creating/updating Kubernetes secret '$Name' in namespace '$Namespace'"

# Ensure namespace exists
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

# Create secret from literals and apply (build YAML then apply to avoid parser issues)
$tempFile = [System.IO.Path]::GetTempFileName()
$yaml = & kubectl create secret generic $Name -n $Namespace --from-literal="DB_HOST=$DbHost" --from-literal="DB_PORT=$DbPort" --from-literal="DB_NAME=$DbName" --from-literal="DB_USER=$DbUser" --from-literal="DB_PASS=$DbPass" --dry-run=client -o yaml
$yaml | Out-File -FilePath $tempFile -Encoding utf8
kubectl apply -f $tempFile
Remove-Item $tempFile -ErrorAction SilentlyContinue

Write-Host "Secret '$Name' applied. You can inspect it with:" 
Write-Host "  kubectl get secret $Name -n $Namespace -o yaml"
