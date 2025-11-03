variable "enable_multi_az" {
  type    = bool
  default = false
  description = "Enable Multi-AZ for RDS (costly). Set true for production only."
}

variable "enable_performance_insights" {
  type    = bool
  default = false
  description = "Enable Performance Insights for RDS. Requires KMS key when enabled."
}

variable "create_rds_pi_kms" {
  type    = bool
  default = false
  description = "Create CMK for RDS Performance Insights. Only used when performance insights enabled."
}

variable "enable_enhanced_monitoring" {
  type    = bool
  default = false
  description = "Enable enhanced monitoring for RDS (costly)."
}

variable "enable_deletion_protection" {
  type    = bool
  default = false
  description = "Enable deletion protection for RDS (prevents accidental deletion)."
}

variable "enable_cloudwatch_logs_exports" {
  type    = bool
  default = false
  description = "Enable exporting RDS logs to CloudWatch (can incur cost)."
}
