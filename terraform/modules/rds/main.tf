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
  
  # Security and monitoring improvements
  storage_encrypted = true
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot = true
  deletion_protection = true
  multi_az = true
  monitoring_interval = 30
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled = true
  performance_insights_kms_key_id = aws_kms_key.rds_pi.key_id
  
  # Enhanced monitoring requires a role
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

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
