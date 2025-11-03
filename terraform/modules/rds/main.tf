# =============================================================================
# RDS Module - Managed PostgreSQL Database
# =============================================================================
# This module creates an Amazon RDS (Relational Database Service) instance
# Think of it as AWS managing a database server for you so you don't have to
# worry about backups, patches, or hardware failures
# =============================================================================

# =============================================================================
# Input Variables
# =============================================================================

variable "identifier" {
  type        = string
  description = "Unique name for the database instance (e.g., 'dev-db')"
}

variable "engine" {
  type        = string
  description = "Database engine type (e.g., 'postgres', 'mysql')"
}

variable "engine_version" {
  type        = string
  description = "Version of the database engine (e.g., '13.7')"
}

variable "instance_class" {
  type        = string
  description = "Size of the database instance (e.g., 'db.t3.micro' for free tier)"
}

variable "storage_gb" {
  type        = number
  description = "Amount of storage in gigabytes (default: 20GB)"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where database will be deployed"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for database placement (use private subnets)"
}

variable "environment" {
  type        = string
  description = "Environment name for tagging (e.g., 'dev', 'prod')"
}

# =============================================================================
# Subnet Group - Database Network Placement
# =============================================================================
# Defines which subnets the database can be placed in (typically private subnets)
resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids # Which subnets database can use

  tags = {
    Name        = "${var.identifier}-subnet-group"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# RDS Database Instance - The Actual Database Server
# =============================================================================
# Checkov skip comments: These features are intentionally disabled by default
# to keep demo costs at $0. Enable them in production via opt-in variables.
#checkov:skip=CKV_AWS_157:Multi-AZ is opt-in for cost control (enable via rds_enable_multi_az)
#checkov:skip=CKV_AWS_118:Enhanced monitoring is opt-in for cost control (enable via rds_enable_enhanced_monitoring)
#checkov:skip=CKV_AWS_353:Performance Insights is opt-in for cost control (enable via rds_enable_performance_insights)
#checkov:skip=CKV_AWS_293:Deletion protection is opt-in for cost control (enable via rds_enable_deletion_protection)
#checkov:skip=CKV_AWS_129:CloudWatch log exports are opt-in for cost control (enable via rds_enable_cloudwatch_log_exports)
#checkov:skip=CKV2_AWS_30:Query logging requires parameter group configuration (implement if needed)
resource "aws_db_instance" "this" {
  identifier        = var.identifier
  engine            = var.engine         # Database type (postgres)
  engine_version    = var.engine_version # Version (13.7)
  instance_class    = var.instance_class # Size (db.t3.micro = free tier eligible)
  allocated_storage = var.storage_gb     # Disk space in GB

  # Database credentials
  db_name  = "${var.environment}_db" # Initial database name
  username = "admin"                 # Master username
  password = random_password.this.result # Auto-generated secure password

  skip_final_snapshot  = true # Don't create snapshot when deleting (faster cleanup for demo)
  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible  = false # NOT accessible from internet (more secure)

  # Always-on security features (no extra cost)
  storage_encrypted          = true # Encrypt data at rest
  auto_minor_version_upgrade = true # Auto-patch security updates
  copy_tags_to_snapshot      = true # Tag snapshots for organization

  # ===== COST-SENSITIVE FEATURES (OPT-IN) =====
  # These default to FALSE to keep demo FREE. Set to TRUE in production.

  deletion_protection = var.enable_deletion_protection # Prevent accidental deletion (FALSE = demo can be easily cleaned up)

  multi_az = var.enable_multi_az # Run in multiple availability zones for HA (FALSE = single zone, FREE)

  monitoring_interval = var.enable_enhanced_monitoring ? 30 : 0 # Enhanced monitoring every 30s (0 = disabled for FREE demo)

  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs_exports ? ["postgresql", "upgrade"] : [] # Send logs to CloudWatch ([] = disabled for FREE)

  performance_insights_enabled = var.enable_performance_insights # Advanced performance metrics (FALSE = FREE)

  performance_insights_kms_key_id = var.create_rds_pi_kms ? try(aws_kms_key.rds_pi[0].key_id, null) : null # KMS key for PI encryption

  monitoring_role_arn = var.enable_enhanced_monitoring ? try(aws_iam_role.rds_monitoring[0].arn, null) : null # IAM role for enhanced monitoring

  tags = {
    Name        = var.identifier
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Random Password Generator
# =============================================================================
# Creates a secure random password for the database admin user
resource "random_password" "this" {
  length  = 20         # 20 characters long
  special = true       # Include special characters (!@#$%)
}

# =============================================================================
# Output - Database Connection Endpoint
# =============================================================================
# Exports the database endpoint so other modules can connect to it
output "endpoint" {
  value       = aws_db_instance.this.endpoint
  description = "Connection endpoint for the RDS database (hostname:port)"
}
