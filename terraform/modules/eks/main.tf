# =============================================================================
# EKS Platform Module
# =============================================================================
# This module creates a complete Amazon EKS (Elastic Kubernetes Service) cluster
# which provides a managed Kubernetes control plane and worker nodes.
#
# Components created:
# - IAM roles and policies for cluster and nodes
# - EKS control plane (managed Kubernetes API server)
# - Worker node groups (EC2 instances running containers)
# - KMS encryption keys (for secrets and EBS volumes)
# - Security groups (firewall rules)
# - Launch templates (node configuration blueprint)
# =============================================================================

# =============================================================================
# Input Variables
# =============================================================================

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster (e.g., 'dev-cluster')"
}

variable "environment" {
  type        = string
  description = "Environment name for tagging (e.g., 'dev', 'staging', 'prod')"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where EKS cluster will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs where EKS nodes will be placed (typically private subnets)"
}

variable "node_groups" {
  type = map(object({
    instance_types = list(string) # EC2 instance types (e.g., ["t3.small"])
    min_size       = number        # Minimum number of nodes (0 = no minimum cost)
    max_size       = number        # Maximum nodes allowed when scaling
    desired_size   = number        # How many nodes to run right now
    disk_size      = number        # GB of storage per node
  }))
  description = "Map of node group configurations - defines the worker nodes that run your containers"
}

# =============================================================================
# IAM Roles - Identity and Access Management
# =============================================================================
# These roles give permissions to the cluster and worker nodes to interact with AWS

# Cluster Role: Allows EKS control plane to manage AWS resources on your behalf
resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  # Trust policy: Defines who can assume this role (EKS service)
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole" # AssumeRole = "put on this role temporarily"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com" # Only EKS service can use this role
        }
      }
    ]
  })
}

# Attach AWS managed policy that gives EKS cluster necessary permissions
resource "aws_iam_role_policy_attachment" "eks_cluster_attach" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" # AWS pre-built policy
}

# Node Role: Allows worker nodes to interact with AWS services and join the cluster
resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-nodes-role"

  # Trust policy: EC2 instances (worker nodes) can assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" # EC2 instances can use this role
        }
      }
    ]
  })
}

# Worker Node Policy: Lets nodes communicate with EKS cluster
resource "aws_iam_role_policy_attachment" "eks_nodes_worker" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# ECR Policy: Allows nodes to pull container images from Amazon's container registry
resource "aws_iam_role_policy_attachment" "eks_nodes_ecr" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# CNI Policy: Enables pod networking (each container gets its own IP address)
resource "aws_iam_role_policy_attachment" "eks_nodes_cni" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# =============================================================================
# EKS Cluster - The Control Plane
# =============================================================================
# This is the "brain" of Kubernetes - manages scheduling, scaling, and orchestration
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28" # Kubernetes version

  # VPC Configuration: Network settings for the cluster
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true  # Cluster API accessible from within VPC
    endpoint_public_access  = false # NOT accessible from internet (more secure)
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  # Encryption: Protects Kubernetes secrets at rest
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn # Use custom KMS key for encryption
    }
    resources = ["secrets"] # Encrypt Kubernetes secrets (passwords, tokens, etc.)
  }

  # Logging: Send cluster logs to CloudWatch for debugging and auditing
  enabled_cluster_log_types = [
    "api",              # API server logs (kubectl commands)
    "audit",            # Audit logs (who did what)
    "authenticator",    # Authentication logs
    "controllerManager", # Controller logs
    "scheduler"         # Scheduling decisions
  ]

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Node Groups - The Worker Nodes
# =============================================================================
# These are the EC2 instances that actually run your containerized applications
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups # Create one node group per entry in the map

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key              # Name like "default"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids        # Which subnets to place nodes in

  instance_types = each.value.instance_types # EC2 instance type (e.g., t3.small)
  disk_size      = each.value.disk_size      # Storage per node in GB

  # Scaling Configuration: How many nodes to run
  scaling_config {
    desired_size = each.value.desired_size # Current target (0 = FREE, no running nodes)
    max_size     = each.value.max_size     # Maximum nodes allowed
    min_size     = each.value.min_size     # Minimum nodes required
  }

  # Launch Template: Custom configuration for each node
  launch_template {
    id      = aws_launch_template.eks_nodes[each.key].id
    version = aws_launch_template.eks_nodes[each.key].latest_version
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    NodeGroup   = each.key
  }
}

# =============================================================================
# Launch Template - Node Configuration Blueprint
# =============================================================================
# Defines how each worker node should be configured when it starts up
resource "aws_launch_template" "eks_nodes" {
  for_each = var.node_groups

  name_prefix = "${var.cluster_name}-${each.key}"

  # Storage Configuration: Encrypted disk for each node
  block_device_mappings {
    device_name = "/dev/xvda" # Root volume device name

    ebs {
      volume_size = each.value.disk_size # Size in GB
      volume_type = "gp3"                # General Purpose SSD (gp3 is cheaper than gp2)
      encrypted   = true                 # Encrypt data at rest
      kms_key_id  = aws_kms_key.ebs.arn  # Use custom KMS key for encryption
    }
  }

  # Metadata Service: Security settings for EC2 instance metadata
  metadata_options {
    http_endpoint               = "enabled"  # Enable metadata service
    http_tokens                 = "required" # Require IMDSv2 (more secure)
    http_put_response_hop_limit = 1          # Limit metadata access to instance only
  }

  # Enable CloudWatch monitoring for nodes
  monitoring {
    enabled = true
  }

  # Spot Instances: Use cheaper spot pricing (can be interrupted)
  # Remove this block if you need guaranteed availability
  instance_market_options {
    market_type = "spot" # Use spot instances to save ~70% on compute costs
  }

  # Tagging for created instances
  tag_specifications {
    resource_type = "instance"
    tags = {
      Environment = var.environment
      ManagedBy   = "terraform"
      NodeGroup   = each.key
    }
  }
}

# =============================================================================
# KMS Keys - Encryption Keys
# =============================================================================
# Custom encryption keys for protecting sensitive data

# KMS Key for EKS Cluster Secrets (passwords, tokens, certificates)
resource "aws_kms_key" "eks" {
  description             = "KMS key for EKS cluster ${var.cluster_name}"
  deletion_window_in_days = 7    # Wait 7 days before permanent deletion (safety buffer)
  enable_key_rotation     = true # Automatically rotate key every year

  # Access Policy: Who can use this encryption key
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"      # Root account has full access
        Resource = "*"
      },
      {
        Sid    = "Allow EKS service to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.eks_cluster.arn # EKS cluster role can use key
        }
        Action = [
          "kms:Encrypt",           # Encrypt secrets
          "kms:Decrypt",           # Decrypt secrets
          "kms:ReEncrypt*",        # Re-encrypt with different key
          "kms:GenerateDataKey*",  # Generate data encryption keys
          "kms:DescribeKey"        # Read key metadata
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# KMS Key for EBS Volumes (node storage encryption)
resource "aws_kms_key" "ebs" {
  description             = "KMS key for EKS node volumes"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  # Access Policy: Who can use this key to encrypt/decrypt EBS volumes
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EC2 nodes to use the key"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.eks_nodes.arn # Worker nodes can encrypt/decrypt their disks
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Security Groups - Firewall Rules
# =============================================================================

# Security Group for EKS Cluster (controls traffic to/from control plane)
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.cluster_name}-cluster"
  vpc_id      = var.vpc_id
  description = "Security group for EKS cluster ${var.cluster_name}"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Allow cluster to make HTTPS calls to AWS APIs (for managing resources)
resource "aws_security_group_rule" "cluster_egress" {
  security_group_id = aws_security_group.eks_cluster.id
  type              = "egress"      # Outbound traffic
  from_port         = 443           # HTTPS port
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] # Allow to anywhere on internet
  description       = "Allow HTTPS egress for EKS cluster"
}