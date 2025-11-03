# =============================================================================
# Terraform Configuration
# =============================================================================
# This file is the "master plan" that orchestrates all AWS infrastructure
# Think of it like a conductor directing an orchestra of cloud resources

terraform {
  # Declare which provider plugins we need (AWS for cloud resources, random for passwords)
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use AWS provider version 5.x
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0" # For generating secure random passwords
    }
  }

  # Backend: Where terraform stores its state (what's currently deployed)
  # Local = saves to disk. Production should use S3 + DynamoDB for team collaboration
  backend "local" {
    # Local backend avoids S3 costs for this demo. For production use an S3 backend with state locking (DynamoDB).
  }
}

# =============================================================================
# AWS Provider Configuration
# =============================================================================
# This tells Terraform how to connect to AWS and sets default tags for all resources
provider "aws" {
  region = var.aws_region # Which AWS region to deploy to (default: us-east-1)
  
  # These tags are automatically applied to every resource we create
  default_tags {
    tags = {
      Environment = var.environment     # e.g., "dev", "staging", "prod"
      Project     = "DevOps-Platform"   # Project identifier
      ManagedBy   = "Terraform"         # Indicates this was created by Terraform
    }
  }
}

# =============================================================================
# Local Variables
# =============================================================================
# Hard-coded values used across modules to keep things simple and low-cost
locals {
  # Use only ONE availability zone to minimize costs (production uses 3+ for redundancy)
  availability_zones   = ["us-east-1a"]
  
  # Subnet CIDR ranges - small address spaces for demo
  private_subnet_cidrs = ["10.0.1.0/24"] # Private subnets: no direct internet access
  public_subnet_cidrs  = ["10.0.2.0/24"] # Public subnets: internet-facing resources
}

# =============================================================================
# VPC Module - Network Foundation
# =============================================================================
# Creates the virtual network (VPC) that all other resources live in
# Like building the roads/infrastructure for a city before adding buildings
module "vpc" {
  count  = var.enable_vpc ? 1 : 0 # Only create if enabled (default: disabled to save costs)
  source = "./modules/networking"  # Points to the networking module folder

  environment        = var.environment           # Pass environment name to module
  vpc_cidr           = var.vpc_cidr             # IP address range for the entire VPC
  availability_zones = local.availability_zones # Which AWS data centers to use
}

# =============================================================================
# EKS Module - Kubernetes Cluster
# =============================================================================
# Creates a managed Kubernetes cluster for running containerized applications
# Think of it as an automated apartment building manager for your apps
module "eks" {
  count  = var.enable_eks ? 1 : 0 # Only create if enabled (default: disabled to save costs)
  source = "./modules/eks"         # Points to the EKS module folder

  cluster_name = "${var.environment}-cluster" # Name like "dev-cluster"
  environment  = var.environment
  vpc_id       = try(module.vpc[0].vpc_id, "")           # Which VPC to deploy into
  subnet_ids   = try(module.vpc[0].private_subnet_ids, []) # Which subnets for worker nodes

  # Node groups define the EC2 instances that run your containers
  # Default to ZERO nodes to avoid costs - scale up when needed
  node_groups = {
    default = {
      instance_types = ["t3.small"] # Small instance type (2 vCPU, 2GB RAM)
      min_size       = 0            # Minimum nodes (0 = FREE)
      desired_size   = 0            # How many nodes you want right now (0 = FREE)
      max_size       = 1            # Maximum nodes allowed to scale to
      disk_size      = 20           # GB of storage per node
    }
  }
}

# =============================================================================
# RDS Module - PostgreSQL Database
# =============================================================================
# Creates a managed PostgreSQL database instance
# Like hiring AWS to run and maintain your database server for you
module "rds" {
  count  = var.enable_rds ? 1 : 0 # Only create if enabled (default: disabled to save costs)
  source = "./modules/rds"         # Points to the RDS module folder

  identifier     = "${var.environment}-db" # Database name like "dev-db"
  engine         = "postgres"              # Database type
  engine_version = "13.7"                  # PostgreSQL version
  instance_class = var.rds_instance_class  # Instance size (default: db.t3.micro for free tier)
  storage_gb     = var.rds_allocated_storage # How much disk space (default: 20GB)

  vpc_id      = try(module.vpc[0].vpc_id, "")           # Which VPC to deploy into
  subnet_ids  = try(module.vpc[0].private_subnet_ids, []) # Which subnets (private = no internet access)
  environment = var.environment

  # Cost-sensitive feature flags - all default to FALSE for free demo
  # Set these to TRUE in production for high availability and monitoring
  enable_multi_az                = var.rds_enable_multi_az                # Duplicate DB across data centers
  enable_performance_insights    = var.rds_enable_performance_insights    # Detailed performance metrics
  create_rds_pi_kms              = var.rds_create_pi_kms                  # Encryption key for insights
  enable_enhanced_monitoring     = var.rds_enable_enhanced_monitoring     # OS-level monitoring
  enable_deletion_protection     = var.rds_enable_deletion_protection     # Prevent accidental deletion
  enable_cloudwatch_logs_exports = var.rds_enable_cloudwatch_log_exports  # Send logs to CloudWatch
}

# =============================================================================
# Monitoring Module - Observability Stack
# =============================================================================
# Sets up Prometheus (metrics) and Grafana (dashboards) for monitoring
# Like installing security cameras and dashboards to watch your infrastructure
module "monitoring" {
  source = "./modules/monitoring" # Points to the monitoring module folder

  cluster_name = try(module.eks[0].cluster_name, "local-cluster") # Which cluster to monitor
  vpc_id       = try(module.vpc[0].vpc_id, "")                   # Which VPC
  subnet_ids   = try(module.vpc[0].private_subnet_ids, [])       # Which subnets
  environment  = var.environment
}