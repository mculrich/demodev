# Lock down default security group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress rules - denies all inbound traffic
  # No egress rules - denies all outbound traffic

  tags = {
    Name        = "${var.environment}-default-sg"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}