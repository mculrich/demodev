## Local Development — Demo Project

This document explains how to run the demo app locally (no AWS cost) using Docker Desktop + Kubernetes (Docker Desktop or kind) and a local Postgres database.

Prerequisites
- Docker Desktop (Kubernetes enabled)
- kubectl configured to the local cluster (docker-desktop or kind)
- PowerShell (Windows) — commands below are PowerShell-friendly
- (optional) AWS CLI if you plan to use External Secrets Operator later

Quickstart (recommended)

1) Start the local Postgres database

```powershell
# from repo root
docker-compose up -d
docker ps --filter name=postgres
```

2) Ensure the `demo` namespace exists and create the Kubernetes Secret with DB credentials

```powershell
# We added a helper script that is idempotent and safe for local dev
.\scripts\create-local-secret.ps1
# verify
kubectl get secret dev-db-creds -n demo -o yaml
```

3) Build the demo Docker image

```powershell
cd .\app
docker build -t demo-app:latest .
cd ..
```

4) Deploy the demo app to the `demo` namespace

```powershell
kubectl apply -f demo-deployment.yaml -n demo
kubectl apply -f demo-service.yaml -n demo
# wait for pod
kubectl get pods -n demo -w
```

5) Access the app

Open http://localhost:30080/ — the app checks the database connection and reports whether Postgres is reachable.

Useful commands
- Show logs:

```powershell
kubectl logs -l app=demo-app -n demo --tail=200
```

- Rebuild + redeploy after code changes

```powershell
docker build -t demo-app:latest ./app
kubectl rollout restart deployment/demo-app -n demo
```

- Remove everything when finished

```powershell
kubectl delete namespace demo
docker-compose down
```

Secrets and production guidance
- For simple local development we store credentials in a Kubernetes Secret created by `scripts/create-local-secret.ps1`. This avoids committing plaintext credentials to the repo.
- For production or cloud deployments, use a provider-backed solution so your cluster gets secrets from a secure source of truth (AWS Secrets Manager, HashiCorp Vault, etc.). Two common options are:
  - External Secrets Operator — syncs Secrets Manager -> Kubernetes Secret (works with apps that read k8s Secrets)
  - Secrets Store CSI Driver + AWS provider — mounts secrets directly from Secrets Manager (can avoid creating k8s Secrets)
- Both operator options are open-source software. You will still incur AWS charges for Secrets Manager and KMS usage.

Next steps (optional)
- Install External Secrets Operator and configure it to sync `dev/demo/db-credentials` into `dev-db-creds` (I can install and configure this for you).
- Convert these manifests into a Helm chart for easier packaging and deployment across environments.

Questions or changes
If you want the README expanded, into a full developer onboarding doc or a Helm-based deploy guide, tell me what you'd like and I'll add it.
