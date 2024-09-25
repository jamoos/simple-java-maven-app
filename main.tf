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


# Variable for AWS Region
variable "aws_region" {
  type        = string
  description = "The AWS region where resources will be created"
}

# Variable for GitHub repository details
variable "github_repository" {
  type = object({
    owner = string
    name  = string
  })
  description = "GitHub repository details (owner and name)"
}

# Variable for the GitHub Actions workflow branch
variable "github_actions_branch" {
  type        = string
  description = "The branch where the GitHub Actions workflow is defined"
}

# OpenID Connect Provider (if not already created)
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint
  ]
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ECR Repository (name based on GitHub repository)
resource "aws_ecr_repository" "github_repo" {
  name                 = var.github_repository.name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions_ecr" {
  name = "github-actions-ecr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:sub" : "repo:${var.github_repository.owner}/${var.github_repository.name}:ref:refs/heads/${var.github_actions_branch}"
          }
        }
      }
    ]
  })
}

# IAM Policy for ECR Access (restrict to the specific repository)
resource "aws_iam_policy" "github_actions_ecr_policy" {
  name = "github-actions-ecr-access"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ],
        Resource = aws_ecr_repository.github_repo.arn
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "github_actions_ecr_attach" {
  role       = aws_iam_role.github_actions_ecr.name
  policy_arn = aws_iam_policy.github_actions_ecr_policy.arn
}

# Output the AWS region (needed for GitHub Actions)
output "aws_region" {
  value = var.aws_region
}
