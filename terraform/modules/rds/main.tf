variable "identifier" { type = string }
variable "engine" { type = string }
variable "engine_version" { type = string }
variable "instance_class" { type = string }
variable "storage_gb" { type = number }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "environment" { type = string }

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name        = "${var.identifier}-subnet-group"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_db_instance" "this" {
  identifier = var.identifier
  engine     = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  allocated_storage = var.storage_gb
  db_name = "${var.environment}_db"
  username = "admin"
  password = random_password.this.result
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.this.name
  publicly_accessible = false
  
  # Security and monitoring improvements (cost-sensitive features are opt-in)
  storage_encrypted = true
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot = true
  deletion_protection = var.enable_deletion_protection
  multi_az = var.enable_multi_az
  monitoring_interval = var.enable_enhanced_monitoring ? 30 : 0
  enabled_cloudwatch_logs_exports = var.enable_cloudwatch_logs_exports ? ["postgresql", "upgrade"] : []
  performance_insights_enabled = var.enable_performance_insights
  performance_insights_kms_key_id = var.create_rds_pi_kms ? try(aws_kms_key.rds_pi[0].key_id, null) : null

  # Enhanced monitoring requires a role (conditional)
  monitoring_role_arn = var.enable_enhanced_monitoring ? try(aws_iam_role.rds_monitoring[0].arn, null) : null

  tags = {
    Name        = var.identifier
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "random_password" "this" {
  length  = 20
  special = true
}

output "endpoint" {
  value = aws_db_instance.this.endpoint
}
