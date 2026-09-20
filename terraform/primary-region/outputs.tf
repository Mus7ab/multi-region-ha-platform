output "vpc_id" {
  value = aws_vpc.main.id
}

output "db_instance_arn" {
  value = aws_db_instance.main.arn
}

output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}
