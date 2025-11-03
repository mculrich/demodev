variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "environment" { type = string }

# Placeholder monitoring module: in a real deployment this would install Prometheus/Grafana via Helm or Terraform providers.
output "monitoring_note" {
  value = "Monitoring module placeholder for cluster ${var.cluster_name} in ${var.environment}"
}
