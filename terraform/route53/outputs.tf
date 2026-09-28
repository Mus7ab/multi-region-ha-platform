output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "name_servers" {
  value = aws_route53_zone.main.name_servers
}

output "record_fqdn" {
  value = "app.${var.zone_name}"
}

output "primary_health_check_id" {
  value = aws_route53_health_check.primary.id
}
