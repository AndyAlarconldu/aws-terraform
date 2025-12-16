terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

#########################
# VPC por defecto
#########################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

#########################
# Imagen Docker
#########################

locals {
  docker_image_repo = "andyxalarcon/aws-terraform-app"
  docker_image_tag  = "1.0.0"
  docker_image      = "${local.docker_image_repo}:${local.docker_image_tag}"
}

#########################
# Security Groups
#########################

# SG del ALB (HTTP desde internet)
resource "aws_security_group" "alb_sg" {
  name        = "${var.app_name}-alb-sg"
  description = "Allow HTTP from internet"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG de EC2 (solo recibe del ALB al puerto 3000)
resource "aws_security_group" "ec2_sg" {
  name        = "${var.app_name}-ec2-sg"
  description = "Allow app traffic from ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "App traffic from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # (Opcional) SSH solo si lo necesitas (recomendado limitar a tu IP)
  # ingress {
  #   description = "SSH"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["TU_IP/32"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#########################
# Load Balancer + Target Group
#########################

resource "aws_lb" "this" {
  name               = "${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "this" {
  name     = "${var.app_name}-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/health"      # ✅ CAMBIO CLAVE
    matcher             = "200-399"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

#########################
# AMI Amazon Linux 2023
#########################

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

#########################
# Launch Template
#########################

resource "aws_launch_template" "this" {
  name_prefix   = "${var.app_name}-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail

    # Amazon Linux 2023 usa dnf (no yum)
    dnf update -y
    dnf install -y docker

    systemctl enable docker
    systemctl start docker

    # Esperar a que docker esté listo
    sleep 5

    # Limpiar contenedor viejo
    docker rm -f app || true

    # Pull + run
    docker pull ${local.docker_image}
    docker run -d --restart always -p 3000:3000 --name app ${local.docker_image}

    # Log para debug
    docker ps
  EOF
  )
}

#########################
# Auto Scaling Group
#########################

resource "aws_autoscaling_group" "this" {
  name                      = "${var.app_name}-asg"
  max_size                  = 4
  min_size                  = 3
  desired_capacity          = 3
  vpc_zone_identifier       = data.aws_subnets.default.ids
  health_check_type         = "ELB"
  health_check_grace_period = 180  # ✅ dale tiempo a instalar docker + pull

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.this.arn]

  tag {
    key                 = "Name"
    value               = "${var.app_name}-instance"
    propagate_at_launch = true
  }
}
