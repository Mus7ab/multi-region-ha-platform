variable "aws_region" {
  description = "AWS region for the secondary (DR) deployment"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix used for tagging all resources"
  type        = string
  default     = "three-tier-webapp-dr"
}

variable "primary_db_arn" {
  description = "ARN of the primary region's RDS instance, for the cross-region read replica"
  type        = string
}
