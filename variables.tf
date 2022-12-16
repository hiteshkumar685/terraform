variable "eks_cluster_domain" {
  type        = string
  description = "Route53 domain for the cluster."
  default     = "devaket.com"
}

variable "acm_certificate_domain" {
  type        = string
  description = "Route53 certificate domain"
  default     = "opnsesame.devaket.com"
}

variable "profile" {
  type = string
  default = "default"
}

variable "region" {
  type = string
  default = "us-east-1"
}

variable "role_arn" {
  type = string
  default = ""
}

variable "vpc_cidr" {
  type = string
  default = "10.0.0.0/16"
}

variable "name" {
  type = string
  default = "tf-hitesh"
}

variable "tags" {
  type = map
  default = {
    Blueprint  = "terraform"
    GithubRepo = "github.com/aws-ia/terraform-aws-eks-blueprints"
  }
}

# For runner

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "runner_name" {
  description = "Name of the runner, will be used in the runner config.toml"
  type        = string
  default     = "default-auto"
}

variable "gitlab_url" {
  description = "URL of the gitlab instance to connect to."
  type        = string
  default     = "https://gitlab.com"
}

variable "registration_token" {
  type = string
  description = "Registration toketn from GitLab > CI/CD > Runners"
  default = ""
}

variable "timezone" {
  description = "Name of the timezone that the runner will be used in."
  type        = string
  default     = "Europe/Minsk"
}
