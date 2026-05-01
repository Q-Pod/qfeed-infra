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

# -----------------------------------------------------------------------------
# Launch Template
# -----------------------------------------------------------------------------

resource "aws_launch_template" "backend" {
  name          = "qfeed-dev-lt-backend"
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
    tags = merge(local.common_tags, {
      Name = "qfeed-dev-ec2-backend"
      Role = "backend"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "qfeed-dev-ec2-backend"
    })
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-lt-backend"
  })
}

# -----------------------------------------------------------------------------
# Auto Scaling Group
# -----------------------------------------------------------------------------

resource "aws_autoscaling_group" "backend" {
  name                = "qfeed-dev-asg-backend"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [data.aws_subnet.public_a.id]
  target_group_arns   = [aws_lb_target_group.backend.arn]

  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  # 앱 배포 전까지 EC2 health check 사용
  # 앱 배포 후 "ELB"로 변경하면 ALB health check 기반 자동 복구 활성화
  health_check_type         = "EC2"
  health_check_grace_period = 300

  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "qfeed-dev-ec2-backend"
      Role = "backend"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# =============================================================================
# AI Server Launch Template
# =============================================================================

resource "aws_launch_template" "ai" {
  name          = "qfeed-dev-lt-ai"
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
    tags = merge(local.common_tags, {
      Name = "qfeed-dev-ec2-ai"
      Role = "ai"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "qfeed-dev-ec2-ai"
    })
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-lt-ai"
  })
}

# -----------------------------------------------------------------------------
# AI Server Auto Scaling Group
# -----------------------------------------------------------------------------

resource "aws_autoscaling_group" "ai" {
  name                = "qfeed-dev-asg-ai"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [data.aws_subnet.public_a.id]

  launch_template {
    id      = aws_launch_template.ai.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "qfeed-dev-ec2-ai"
      Role = "ai"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# =============================================================================
# Monitoring Server Launch Template
# =============================================================================

resource "aws_launch_template" "monitoring" {
  name          = "qfeed-dev-lt-monitoring"
  image_id      = var.ami_id
  instance_type = "t4g.medium"
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_monitoring.name
  }

  vpc_security_group_ids = [aws_security_group.monitoring.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # 데이터 볼륨 (Prometheus/Loki/Grafana 데이터 저장)
  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      delete_on_termination = false
      encrypted             = true
    }
  }

  user_data = base64encode(local.base_user_data)

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "qfeed-dev-ec2-monitoring"
      Role = "monitoring"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "qfeed-dev-ec2-monitoring"
    })
  }

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-lt-monitoring"
  })
}

# -----------------------------------------------------------------------------
# Monitoring Server Auto Scaling Group
# -----------------------------------------------------------------------------

resource "aws_autoscaling_group" "monitoring" {
  name                = "qfeed-dev-asg-monitoring"
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1
  vpc_zone_identifier = [data.aws_subnet.public_a.id]

  launch_template {
    id      = aws_launch_template.monitoring.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "qfeed-dev-ec2-monitoring"
      Role = "monitoring"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
