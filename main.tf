terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  backend "s3" {
    bucket         = "kafri-tfstate"
    key            = "state/maven.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "kafri-tfstate-lock"
  }
}



# ECR Repository
resource "aws_ecr_repository" "simple-java-maven-app" {
  name                 = "simple-java-maven-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# IAM Role
resource "aws_iam_role" "github_actions_ecr" {
  name = "github_actions_ecr"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for ECR Repository Access
data "aws_iam_policy_document" "github_actions_ecr_policy" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken", # Required for ECR login
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]

    resources = [
      aws_ecr_repository.simple-java-maven-app.arn
    ]
  }
}

# Attach Policy to Role
resource "aws_iam_role_policy" "github_actions_ecr_access" {
  name   = "github_actions_ecr_access"
  role   = aws_iam_role.github_actions_ecr.id
  policy = data.aws_iam_policy_document.github_actions_ecr_policy.json
}

# Output for GitHub Actions Secrets
output "github_actions_secrets" {
  value = {
    AWS_ROLE_ARN = aws_iam_role.github_actions_ecr.arn
    AWS_REGION   = var.aws_region
  }
}

variable "aws_region" {
  type        = string
  description = "The AWS region where resources will be created"
}
