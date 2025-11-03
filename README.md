# Enterprise Infrastructure Demo Project

This repository demonstrates modern DevOps practices and infrastructure automation for enterprise environments. It showcases the implementation of a scalable, secure, and automated infrastructure platform using AWS, Terraform, Kubernetes, and industry-standard monitoring solutions.

## Key Features

- Infrastructure as Code (IaC) using Terraform
- Kubernetes cluster setup and management
- CI/CD pipelines with GitHub Actions
- Comprehensive monitoring and alerting setup
- Personal development environments automation
- Security best practices implementation

## Project Components

1. **Infrastructure as Code**
   - AWS infrastructure provisioning
   - Network architecture (VPC, subnets, security groups)
   - EKS cluster configuration
   - RDS database setup
   - IAM roles and policies

2. **Kubernetes Configuration**
   - EKS cluster management
   - Application deployments
   - Service mesh integration
   - Auto-scaling policies
   - Resource management

3. **CI/CD Pipeline**
   - GitHub Actions workflows
   - Automated testing
   - Security scanning
   - Deployment automation
   - Environment promotion

4. **Monitoring Stack**
   - Prometheus + Grafana setup
   - Custom dashboards
   - Alert configuration
   - Log aggregation
   - Performance metrics

5. **Developer Tooling**
   - Local development environment setup
   - Feature environment automation
   - Development workflow documentation
   - Troubleshooting guides

## Repository Structure

```
.
├── terraform/               # Infrastructure as Code
├── kubernetes/             # Kubernetes configurations
├── .github/
│   └── workflows/         # CI/CD pipeline definitions
├── monitoring/            # Monitoring configurations
├── scripts/              # Utility scripts
└── docs/                 # Documentation
```

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0.0
- kubectl
- Docker
- Helm

## Quickstart — Local demo (no AWS required)

Follow these minimal steps to run the demo app locally using Docker Desktop and your local Kubernetes (docker-desktop or kind). These are PowerShell-friendly commands — a longer guide is available at `docs/development.md`.

1) Start local Postgres

```powershell
docker-compose up -d
```

2) Create the Kubernetes secret with DB credentials (idempotent)

```powershell
.\scripts\create-local-secret.ps1
```

3) Build the demo Docker image

```powershell
cd .\app
docker build -t demo-app:latest .
cd ..
```

4) Deploy the demo app

```powershell
kubectl apply -f demo-deployment.yaml -n demo
kubectl apply -f demo-service.yaml -n demo
kubectl get pods -n demo -w
```

5) Open the app

Open http://localhost:30080/ — the app will report whether it can reach the local Postgres instance.

Cleanup

```powershell
kubectl delete namespace demo
docker-compose down
```

Notes:
- For a more detailed development workflow see `docs/development.md` (including optional kind setup and External Secrets guidance).
- For production, use a secrets integration (External Secrets Operator or Secrets Store CSI) with AWS Secrets Manager; do not commit plaintext credentials to git.

## Getting Started

1. Clone this repository
2. Configure AWS credentials
3. Initialize Terraform:
   ```
   cd terraform
   terraform init
   ```
4. Apply infrastructure:
   ```
   terraform apply
   ```
5. Configure kubectl:
   ```
   aws eks update-kubeconfig --name <cluster-name> --region <region>
   ```

## Documentation

Detailed documentation for each component is available in the `docs/` directory:

- [Infrastructure Setup](docs/infrastructure.md)
- [Kubernetes Deployment Guide](docs/kubernetes.md)
- [Monitoring Configuration](docs/monitoring.md)
- [CI/CD Pipeline](docs/cicd.md)
- [Development Guide](docs/development.md)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details