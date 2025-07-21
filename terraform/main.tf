terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# VPC with public subnets for EC2, RDS, and ALB
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.0.2"

  name = "greeting-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ca-central-1a", "ca-central-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "greeting-app"
  }
}

# main.tf

# Create ECS Cluster
resource "aws_ecs_cluster" "flask_cluster" {
  name = "flask-cluster"
}

# IAM Role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "flask_task" {
  family                   = "flask-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = jsonencode([{
    name      = "flask-container",
    image     = "${var.aws_account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repo_name}:latest",
    essential = true,
    portMappings = [{
      containerPort = 5000,
      hostPort      = 5000
    }],
    environment = [
      { name = "DB_HOST", value = aws_db_instance.postgres.address },
      { name = "DB_NAME", value = aws_db_instance.postgres.db_name },
      { name = "DB_USER", value = var.db_username },
      { name = "DB_PASS", value = var.db_password }
    ]
  }])
}

# ECS Fargate Service
resource "aws_ecs_service" "flask_service" {
  name            = "flask-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.flask_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets         = module.vpc.public_subnets
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "flask-container"
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.app_listener]
}

# ECS Security Group
resource "aws_security_group" "ecs_sg" {
  name   = "ecs_sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
