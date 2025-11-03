terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "local" {
    # Local backend avoids S3 costs for this demo. For production use an S3 backend with state locking (DynamoDB).
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "DevOps-Platform"
      ManagedBy   = "Terraform"
    }
  }
}

# Keep things small and low-cost: single AZ, minimal CIDRs
locals {
  availability_zones   = ["us-east-1a"]
  private_subnet_cidrs = ["10.0.1.0/24"]
  public_subnet_cidrs  = ["10.0.2.0/24"]
}

module "vpc" {
  count  = var.enable_vpc ? 1 : 0
  source = "./modules/networking"

  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = local.availability_zones
}

# EKS cluster with zero-sized node groups by default to avoid EC2 costs.
# In production you would provision managed node groups or use Fargate profiles.
module "eks" {
  count  = var.enable_eks ? 1 : 0
  source = "./modules/eks"

  cluster_name = "${var.environment}-cluster"
  environment  = var.environment
  vpc_id       = try(module.vpc[0].vpc_id, "")
  subnet_ids   = try(module.vpc[0].private_subnet_ids, [])

  node_groups = {
    default = {
      instance_types = ["t3.small"]
      min_size       = 0
      desired_size   = 0
      max_size       = 1
      disk_size      = 20
    }
  }
}

# RDS - smallest reasonable instance for demo (free-tier eligible in many accounts)
module "rds" {
  count  = var.enable_rds ? 1 : 0
  source = "./modules/rds"

  identifier     = "${var.environment}-db"
  engine         = "postgres"
  engine_version = "13.7"
  instance_class = var.rds_instance_class
  storage_gb     = var.rds_allocated_storage

  vpc_id      = try(module.vpc[0].vpc_id, "")
  subnet_ids  = try(module.vpc[0].private_subnet_ids, [])
  environment = var.environment

  # Cost-sensitive feature flags (opt-in)
  enable_multi_az                = var.rds_enable_multi_az
  enable_performance_insights    = var.rds_enable_performance_insights
  create_rds_pi_kms              = var.rds_create_pi_kms
  enable_enhanced_monitoring     = var.rds_enable_enhanced_monitoring
  enable_deletion_protection     = var.rds_enable_deletion_protection
  enable_cloudwatch_logs_exports = var.rds_enable_cloudwatch_log_exports
}

# Monitoring module (prometheus/grafana) - lightweight defaults
module "monitoring" {
  source = "./modules/monitoring"

  cluster_name = try(module.eks[0].cluster_name, "local-cluster")
  vpc_id       = try(module.vpc[0].vpc_id, "")
  subnet_ids   = try(module.vpc[0].private_subnet_ids, [])
  environment  = var.environment
}