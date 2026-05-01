# =============================================================================
# 공통 user_data (Docker + SSM Agent + AWS CLI)
# =============================================================================

locals {
  base_user_data = <<-USERDATA
#!/bin/bash
set -euxo pipefail

# Timezone
timedatectl set-timezone Asia/Seoul

# Docker
apt-get update -y
apt-get install -y ca-certificates curl unzip
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
usermod -aG docker ubuntu
systemctl enable docker
systemctl start docker

# SSM Agent
cd /tmp
wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_arm64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# AWS CLI v2 (ARM64)
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip -qo awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws
USERDATA
}

# =============================================================================
# Backend EC2 (ASG 1~4, 초기 배포 검증용 — 트래픽 전환 시 min/desired 2로 변경)
# =============================================================================

resource "aws_launch_template" "backend" {
  name          = "qfeed-prod-lt-backend"
  image_id      = var.ami_id
  instance_type = "t4g.small"
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_backend.name
  }

  vpc_security_group_ids = [aws_security_group.backend.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(local.base_user_data)

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, { Name = "qfeed-prod-ec2-backend" })
  }
  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, { Name = "qfeed-prod-ec2-backend" })
  }
  tags = merge(local.common_tags, { Name = "qfeed-prod-lt-backend" })
}

resource "aws_autoscaling_group" "backend" {
  name                = "qfeed-prod-asg-backend"
  min_size            = 1   # TODO: 실 트래픽 전환 시 2로 변경
  max_size            = 4
  desired_capacity    = 1   # TODO: 실 트래픽 전환 시 2로 변경
  vpc_zone_identifier = [aws_subnet.private_app_a.id]
  target_group_arns   = [aws_lb_target_group.backend.arn]

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "qfeed-prod-ec2-backend" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# =============================================================================
# AI EC2 (ASG 1)
# =============================================================================

resource "aws_launch_template" "ai" {
  name          = "qfeed-prod-lt-ai"
  image_id      = var.ami_id
  instance_type = "t4g.small"
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ai.name
  }

  vpc_security_group_ids = [aws_security_group.ai.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(local.base_user_data)

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, { Name = "qfeed-prod-ec2-ai" })
  }
  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, { Name = "qfeed-prod-ec2-ai" })
  }
  tags = merge(local.common_tags, { Name = "qfeed-prod-lt-ai" })
}

resource "aws_autoscaling_group" "ai" {
  name                = "qfeed-prod-asg-ai"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [aws_subnet.private_app_a.id]

  launch_template {
    id      = aws_launch_template.ai.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "qfeed-prod-ec2-ai" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# =============================================================================
# Redis EC2 (고정 1대, user_data에서 Redis 컨테이너 기동)
# =============================================================================

resource "aws_launch_template" "redis" {
  name          = "qfeed-prod-lt-redis"
  image_id      = var.ami_id
  instance_type = "t4g.micro"
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_redis.name
  }

  vpc_security_group_ids = [aws_security_group.redis.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(<<-USERDATA
${local.base_user_data}

# Redis 컨테이너 기동
REDIS_PASSWORD=$(aws ssm get-parameter \
  --region ap-northeast-2 \
  --name "/qfeed/prod/be/REDIS_PASSWORD" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text)

docker run -d \
  --name redis \
  --network host \
  --restart unless-stopped \
  --log-driver json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -v redis-data:/data \
  redis:7-alpine \
  redis-server \
    --appendonly yes \
    --maxmemory 512mb \
    --maxmemory-policy allkeys-lru \
    --requirepass "$REDIS_PASSWORD" \
    --bind 0.0.0.0
USERDATA
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, { Name = "qfeed-prod-ec2-redis" })
  }
  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, { Name = "qfeed-prod-ec2-redis" })
  }
  tags = merge(local.common_tags, { Name = "qfeed-prod-lt-redis" })
}

resource "aws_autoscaling_group" "redis" {
  name                = "qfeed-prod-asg-redis"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [aws_subnet.private_app_a.id]

  launch_template {
    id      = aws_launch_template.redis.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "qfeed-prod-ec2-redis" })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
