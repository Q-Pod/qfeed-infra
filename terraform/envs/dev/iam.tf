# =============================================================================
# Backend EC2 IAM Role
# =============================================================================

resource "aws_iam_role" "ec2_backend" {
  name = "qfeed-dev-role-ec2-backend"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-role-ec2-backend"
  })
}

# -----------------------------------------------------------------------------
# Backend - SSM Parameter Store 읽기 권한 (/qfeed/dev/*)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ssm_params" {
  name = "qfeed-dev-policy-ssm"
  role = aws_iam_role.ec2_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:ap-northeast-2:*:parameter/qfeed/dev/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Backend - ECR Pull 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ecr" {
  name = "qfeed-dev-policy-ecr"
  role = aws_iam_role.ec2_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Backend - S3 읽기/쓰기 권한 (dev 버킷 전체)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "s3" {
  name = "qfeed-dev-policy-s3"
  role = aws_iam_role.ec2_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::qfeed-dev-s3-*",
          "arn:aws:s3:::qfeed-dev-s3-*/*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Backend - CloudWatch Logs 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "qfeed-dev-policy-cloudwatch-logs"
  role = aws_iam_role.ec2_backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:ap-northeast-2:*:log-group:/qfeed/dev/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Backend - SSM Session Manager 접속 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# Backend - Instance Profile
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "ec2_backend" {
  name = "qfeed-dev-profile-ec2-backend"
  role = aws_iam_role.ec2_backend.name

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-profile-ec2-backend"
  })
}

# =============================================================================
# AI Server EC2 IAM Role
# =============================================================================

resource "aws_iam_role" "ec2_ai" {
  name = "qfeed-dev-role-ec2-ai"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-role-ec2-ai"
  })
}

# -----------------------------------------------------------------------------
# AI - SSM Parameter Store 읽기 권한 (/qfeed/dev/*)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ai_ssm_params" {
  name = "qfeed-dev-policy-ai-ssm"
  role = aws_iam_role.ec2_ai.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:ap-northeast-2:*:parameter/qfeed/dev/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AI - ECR Pull 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ai_ecr" {
  name = "qfeed-dev-policy-ai-ecr"
  role = aws_iam_role.ec2_ai.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AI - S3 읽기/쓰기 권한 (dev 버킷 전체)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ai_s3" {
  name = "qfeed-dev-policy-ai-s3"
  role = aws_iam_role.ec2_ai.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::qfeed-dev-s3-*",
          "arn:aws:s3:::qfeed-dev-s3-*/*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AI - CloudWatch Logs 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ai_cloudwatch_logs" {
  name = "qfeed-dev-policy-ai-cloudwatch-logs"
  role = aws_iam_role.ec2_ai.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:ap-northeast-2:*:log-group:/qfeed/dev/*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# AI - SSM Session Manager 접속 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ai_ssm_managed" {
  role       = aws_iam_role.ec2_ai.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# AI - Instance Profile
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "ec2_ai" {
  name = "qfeed-dev-profile-ec2-ai"
  role = aws_iam_role.ec2_ai.name

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-profile-ec2-ai"
  })
}

# =============================================================================
# Monitoring EC2 IAM Role
# =============================================================================

resource "aws_iam_role" "ec2_monitoring" {
  name = "qfeed-dev-role-ec2-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-role-ec2-monitoring"
  })
}

# -----------------------------------------------------------------------------
# Monitoring - EC2 DescribeInstances (Prometheus ec2_sd_configs — Dev+Prod)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "monitoring_ec2_describe" {
  name = "qfeed-dev-policy-monitoring-ec2-describe"
  role = aws_iam_role.ec2_monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ec2:DescribeInstances"
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Monitoring - CloudWatch 읽기 권한 (Grafana CloudWatch 데이터소스)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "monitoring_cloudwatch" {
  name = "qfeed-dev-policy-monitoring-cloudwatch"
  role = aws_iam_role.ec2_monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DescribeAlarmsForMetric"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Monitoring - SSM Session Manager 접속 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "monitoring_ssm_managed" {
  role       = aws_iam_role.ec2_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# -----------------------------------------------------------------------------
# Monitoring - Instance Profile
# -----------------------------------------------------------------------------

resource "aws_iam_instance_profile" "ec2_monitoring" {
  name = "qfeed-dev-profile-ec2-monitoring"
  role = aws_iam_role.ec2_monitoring.name

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-profile-ec2-monitoring"
  })
}

# =============================================================================
# GitHub Actions IAM Role
# =============================================================================

resource "aws_iam_role" "github_actions" {
  name = "qfeed-dev-role-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github_actions.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:100-hours-a-week/17-JinyUs-Q-Feed-BE:ref:refs/heads/*",
              "repo:100-hours-a-week/17-JinyUs-Q-Feed-AI:ref:refs/heads/*",
            ]
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "qfeed-dev-role-github-actions"
  })
}

# -----------------------------------------------------------------------------
# GitHub Actions - ECR Push 권한
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "qfeed-dev-policy-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeImages",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = [
          aws_ecr_repository.backend.arn,
          aws_ecr_repository.ai.arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# GitHub Actions - SSM Run Command 권한 (EC2에 배포 명령 전송)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "github_actions_ssm_send_command" {
  name = "qfeed-dev-policy-github-actions-ssm"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ssm:ap-northeast-2::document/AWS-RunShellScript"
      },
      {
        Effect   = "Allow"
        Action   = "ssm:SendCommand"
        Resource = "arn:aws:ec2:ap-northeast-2:*:instance/*"
        Condition = {
          StringEquals = {
            "ssm:resourceTag/Project"     = "qfeed"
            "ssm:resourceTag/Environment" = "dev"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# GitHub Actions - S3 업로드 권한 (deploy 파일 전송용)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "github_actions_s3" {
  name = "qfeed-dev-policy-github-actions-s3"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::qfeed-dev-s3-*",
          "arn:aws:s3:::qfeed-dev-s3-*/*"
        ]
      }
    ]
  })
}

