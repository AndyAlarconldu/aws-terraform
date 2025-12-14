output "alb_dns_name" {
  description = "URL pública del Load Balancer"
  value       = aws_lb.this.dns_name
}
