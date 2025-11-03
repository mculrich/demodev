# =============================================================================
# Network Infrastructure Module
# =============================================================================
# This module creates the foundational networking for your AWS infrastructure
# Think of it as building the roads, highways, and neighborhoods where your
# applications will live
# =============================================================================

# =============================================================================
# Input Variables
# =============================================================================

variable "vpc_cidr" {
  type        = string
  description = "IP address range for the VPC (e.g., '10.0.0.0/16' = 65,536 IP addresses)"
}

variable "environment" {
  type        = string
  description = "Environment name for tagging (e.g., 'dev', 'staging', 'prod')"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of AWS availability zones to use (e.g., ['us-east-1a', 'us-east-1b'])"
}

# =============================================================================
# VPC - Virtual Private Cloud
# =============================================================================
# Your own isolated network in AWS - like having your own private data center
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr       # IP address range
  enable_dns_hostnames = true               # Assign DNS names to instances
  enable_dns_support   = true               # Enable DNS resolution

  tags = {
    Name        = "${var.environment}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Private Subnets - Internal Network Segments
# =============================================================================
# Private subnets have NO direct internet access - perfect for databases and internal services
# Resources here can access internet through NAT Gateway but internet cannot reach them directly
resource "aws_subnet" "private" {
  count             = length(var.availability_zones) # Create one per AZ
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index) # Auto-calculate subnet CIDR
  availability_zone = var.availability_zones[count.index]      # Place in specific AZ

  tags = {
    Name        = "${var.environment}-private-${count.index + 1}"
    Environment = var.environment
    Type        = "private"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Public Subnets - Internet-Facing Network Segments
# =============================================================================
# Public subnets CAN access internet directly - used for load balancers and NAT gateways
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + length(var.availability_zones)) # Different CIDR than private
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.environment}-public-${count.index + 1}"
    Environment = var.environment
    Type        = "public"
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# NAT Gateway - Internet Access for Private Subnets
# =============================================================================
# NAT (Network Address Translation) Gateway allows private subnet resources to
# access the internet (for updates, API calls) while staying protected from
# inbound internet traffic. Think of it as a one-way door to the internet.

# Elastic IP for NAT Gateway (static public IP address)
resource "aws_eip" "nat" {
  count  = length(var.availability_zones) # One per AZ for high availability
  domain = "vpc"                          # EIP for use in VPC (not EC2-Classic)

  tags = {
    Name        = "${var.environment}-nat-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# NAT Gateway itself (sits in public subnet, routes traffic for private subnets)
resource "aws_nat_gateway" "main" {
  count         = length(var.availability_zones)
  allocation_id = aws_eip.nat[count.index].id     # Attach elastic IP
  subnet_id     = aws_subnet.public[count.index].id # Place in public subnet

  tags = {
    Name        = "${var.environment}-nat-${count.index + 1}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Security Groups - Firewall Rules
# =============================================================================

# Common Security Group: Shared firewall rules for resources in this VPC
#checkov:skip=CKV2_AWS_5:Common security group is a shared resource template (attach to resources as needed)
resource "aws_security_group" "common" {
  name        = "${var.environment}-common"
  description = "Common security group for ${var.environment}"
  vpc_id      = aws_vpc.main.id

  # Ingress Rule: Allow ALL traffic from within the VPC
  # This means any resource with this SG can talk to any other resource in the VPC
  ingress {
    from_port   = 0                # All ports
    to_port     = 0                # All ports
    protocol    = "-1"             # All protocols (TCP, UDP, ICMP, etc.)
    cidr_blocks = [var.vpc_cidr]   # Only from VPC IP range
    description = "Allow all traffic within the VPC"
  }

  # Egress Rule: Allow outbound traffic ONLY to the VPC
  # This restricts resources from accessing the internet directly
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]   # Only to VPC IP range (no internet)
    description = "Restrict egress to the VPC CIDR"
  }

  tags = {
    Name        = "${var.environment}-common"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}