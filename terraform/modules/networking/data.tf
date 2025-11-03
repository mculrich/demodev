# Get current AWS account ID for policies
data "aws_caller_identity" "current" {}

# Get current AWS region
data "aws_region" "current" {}