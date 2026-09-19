output "alb_dns_name" {
  description = "DNS name of the secondary region's ALB"
  value       = aws_lb.main.dns_name
}

output "vpc_id" {
  description = "Secondary region VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (for RDS replica later)"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}
