# -----------------------------------------------------------------------------
# 기존 리소스 참조
# -----------------------------------------------------------------------------

data "aws_vpc" "dev" {
  id = "vpc-0d485c5cc8bf9405f"
}

data "aws_subnet" "public_a" {
  id = "subnet-0fe5c16b894d665a2"
}

data "aws_route_table" "public" {
  route_table_id = "rtb-0b63e02b969268081"
}

# RDS 마스터 비밀번호 (SSM Parameter Store SecureString)
data "aws_ssm_parameter" "db_password" {
  name = "/qfeed/dev/db-password"
}

# CloudFront origin-facing prefix list (ALB SG에서 사용)
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# Prod VPC (VPC 피어링 + 모니터링 SG에서 Prod CIDR 참조)
data "aws_vpc" "prod" {
  id = "vpc-0cd05ba717f09a29e"
}

# OIDC Provider (CLI로 생성 완료, data source로 참조)
data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}
