variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "gitops-eks"
}

variable "environment" {
  type    = string
  default = "dev"
}