variable "zone_name" {
  description = "Test-only domain name (unregistered, not publicly delegated)"
  type        = string
  default     = "project7-drtest.com"
}

variable "primary_alb_dns_name" {
  type = string
}

variable "primary_alb_zone_id" {
  type = string
}

variable "secondary_alb_dns_name" {
  type = string
}

variable "secondary_alb_zone_id" {
  type = string
}
