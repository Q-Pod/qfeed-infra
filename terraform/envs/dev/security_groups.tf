# -----------------------------------------------------------------------------
# ALB Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "qfeed-dev-sg-alb"
  description = "ALB - allow HTTP from CloudFront"
  vpc_id      = data.aws_vpc.dev.id

  ingress {
    description     = "HTTP from CloudFront"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sg-alb"
  })
}

# -----------------------------------------------------------------------------
# Backend EC2 Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "backend" {
  name        = "qfeed-dev-sg-backend"
  description = "Backend EC2 - allow 8080 from ALB, 22 from team IPs"
  vpc_id      = data.aws_vpc.dev.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sg-backend"
  })
}

# -----------------------------------------------------------------------------
# AI Server EC2 Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "ai" {
  name        = "qfeed-dev-sg-ai"
  description = "AI EC2 - allow 8000 from Backend SG, 22 from team IPs"
  vpc_id      = data.aws_vpc.dev.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sg-ai"
  })
}

# -----------------------------------------------------------------------------
# RDS Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "rds" {
  name        = "qfeed-dev-sg-rds"
  description = "RDS - allow 5432 from Backend and team IPs"
  vpc_id      = data.aws_vpc.dev.id

  ingress {
    description     = "PostgreSQL from Backend"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  # TODO: Bigbang EC2 terminate 후 제거
  ingress {
    description     = "from dev ec2 bigbang (tmp)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["sg-0d3ad013112868346"]
  }

  # TODO: DB 마이그레이션 완료 후 제거
  ingress {
    description     = "PostgreSQL from replication instance for migration (tmp)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = ["sg-01d41087429d081b4"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sg-rds"
  })
}

# -----------------------------------------------------------------------------
# Monitoring EC2 Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "monitoring" {
  name        = "qfeed-dev-sg-monitoring"
  description = "Monitoring EC2 - Loki push from Dev/Prod, no external Grafana access"
  vpc_id      = data.aws_vpc.dev.id

  # Loki push (3100) from Dev Backend/AI SG
  ingress {
    description     = "Loki push from Dev Backend"
    from_port       = 3100
    to_port         = 3100
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  ingress {
    description     = "Loki push from Dev AI"
    from_port       = 3100
    to_port         = 3100
    protocol        = "tcp"
    security_groups = [aws_security_group.ai.id]
  }

  # Loki push (3100) from Prod VPC (VPC 피어링 경유)
  ingress {
    description = "Loki push from Prod VPC (peering)"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Grafana (3000) — 외부 인바운드 없음. SSM Port Forwarding으로 접근.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-sg-monitoring"
  })
}

# -----------------------------------------------------------------------------
# Backend SG — ingress rules
# inline과 aws_security_group_rule 혼용 방지를 위해 전부 별도 rule로 관리
# -----------------------------------------------------------------------------

resource "aws_security_group_rule" "backend_from_alb_http" {
  type                     = "ingress"
  description              = "HTTP from ALB"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "backend_from_alb_actuator" {
  type                     = "ingress"
  description              = "Actuator health check from ALB"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "backend_ssh" {
  type              = "ingress"
  description       = "SSH from team IPs"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.backend.id
  cidr_blocks       = var.allowed_ips
}

# -----------------------------------------------------------------------------
# AI SG — ingress rules
# -----------------------------------------------------------------------------

resource "aws_security_group_rule" "ai_from_backend" {
  type                     = "ingress"
  description              = "FastAPI from Backend"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ai.id
  source_security_group_id = aws_security_group.backend.id
}

# TODO: Bigbang EC2 terminate 후 제거
resource "aws_security_group_rule" "ai_from_bigbang" {
  type              = "ingress"
  description       = "FastAPI from Bigbang (temporary)"
  from_port         = 8000
  to_port           = 8000
  protocol          = "tcp"
  security_group_id = aws_security_group.ai.id
  cidr_blocks       = ["10.1.2.58/32"]
}

resource "aws_security_group_rule" "ai_ssh" {
  type              = "ingress"
  description       = "SSH from team IPs"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.ai.id
  cidr_blocks       = var.allowed_ips
}

# -----------------------------------------------------------------------------
# Monitoring scrape 허용 (Backend/AI SG ← 모니터링 SG)
# -----------------------------------------------------------------------------

resource "aws_security_group_rule" "backend_from_monitoring_actuator" {
  type                     = "ingress"
  description              = "Actuator/Prometheus scrape from Monitoring"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.monitoring.id
}

resource "aws_security_group_rule" "backend_from_monitoring_alloy" {
  type                     = "ingress"
  description              = "Alloy metrics scrape from Monitoring"
  from_port                = 12345
  to_port                  = 12345
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.monitoring.id
}

resource "aws_security_group_rule" "ai_from_monitoring_fastapi" {
  type                     = "ingress"
  description              = "FastAPI /metrics scrape from Monitoring"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ai.id
  source_security_group_id = aws_security_group.monitoring.id
}

resource "aws_security_group_rule" "ai_from_monitoring_alloy" {
  type                     = "ingress"
  description              = "Alloy metrics scrape from Monitoring"
  from_port                = 12345
  to_port                  = 12345
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ai.id
  source_security_group_id = aws_security_group.monitoring.id
}
