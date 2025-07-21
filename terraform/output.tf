# Output for RDS PostgreSQL endpoint
output "db_endpoint" {
  description = "The endpoint of the PostgreSQL RDS instance"
  value       = aws_db_instance.postgres.address
}

# Output for EC2 public IP
output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.flask_ec2.public_ip
}

output "ecr_repo_url" {
  value = aws_ecr_repository.greeting_app.repository_url
}

output "alb_dns" {
  value = aws_lb.app_alb.dns_name
}

output "db_name" {
  value = aws_db_instance.postgres.db_name
}
