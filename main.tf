# Modified by HK
provider "aws" {
  region  = var.region
  profile = var.profile
  # assume_role {
  #   role_arn = var.role
  # }
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }
  host                   = module.eks_blueprints.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}


provider "helm" {
  debug = true
  kubernetes {
    host                   = module.eks_blueprints.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_blueprints.eks_cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}



data "aws_eks_cluster_auth" "this" {
  name = module.eks_blueprints.eks_cluster_id
}


data "aws_acm_certificate" "issued" {
  # provider = aws.cert
  domain   = var.acm_certificate_domain
  statuses = ["ISSUED","EXPIRED"]
}

data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}



#---------------------------------------------------------------
# EKS Blueprints
#---------------------------------------------------------------

module "eks_blueprints" {
  source = "../terraform-aws-eks-blueprints"

  cluster_name    = var.name
  cluster_version = "1.23"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  create_iam_role = false
  iam_role_arn = "arn:aws:iam::711622768521:role/terraform-cluster-role"

  managed_node_groups = {
    mg_5 = {
      node_group_name = "managed-ondemand"
      instance_types  = ["m5.large"]
      min_size        = 2
      subnet_ids      = module.vpc.private_subnets
      pre_userdata = <<-EOT
        /sbin/iptables -t nat -A PREROUTING -d 10.0.2.15 \
          -i cali+ -p tcp -m tcp --dport 80 -j DNAT \
          --to-destination $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4):8181
      EOT
    }
  }

  tags = var.tags
}

module "eks_blueprints_kubernetes_addons" {
  source = "../terraform-aws-eks-blueprints/modules/kubernetes-addons"

  eks_cluster_id       = module.eks_blueprints.eks_cluster_id
  eks_cluster_endpoint = module.eks_blueprints.eks_cluster_endpoint
  eks_oidc_provider    = module.eks_blueprints.oidc_provider
  eks_cluster_version  = module.eks_blueprints.eks_cluster_version
  eks_cluster_domain   = var.eks_cluster_domain

  enable_argocd = true
  argocd_applications = {
    workloads = {
      path     = "envs/dev"
      repo_url = "https://github.com/aws-samples/eks-blueprints-workloads.git"
      values = {
        spec = {
          ingress = {
            host = var.eks_cluster_domain
          }
        }
      }
    }
  }

  enable_ingress_nginx = true
  ingress_nginx_helm_config = {
    
    values = [templatefile("${path.module}/nginx-values.yaml", {
      hostname     = var.eks_cluster_domain
      ssl_cert_arn = data.aws_acm_certificate.issued.arn
    })]
  }
  

  enable_aws_load_balancer_controller = true
  enable_external_dns                 = true

  tags = var.tags

}



#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = var.name
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 10)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Manage so we can name
  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.name}-default" }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/elb"            = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.name}" = "shared"
    "kubernetes.io/role/internal-elb"   = 1
  }

  tags = var.tags
}

module "gitlab-runner" {
  source  = "npalm/gitlab-runner/aws"
  version = "4.41.1"

  aws_region  = var.region
  environment = "gitlab-runner"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids_gitlab_runner = module.vpc.private_subnets
  subnet_id_runners        = element(module.vpc.private_subnets, 0)

  runners_name             = var.runner_name
  runners_gitlab_url       = var.gitlab_url
  enable_runner_ssm_access = true
  enable_eip               = false

  docker_machine_spot_price_bid = "0.10"
  docker_machine_instance_type  = "c4.large"

  gitlab_runner_registration_config = {
    registration_token = var.registration_token
    tag_list           = "terraform_deploy"
    description        = "terraform deploy runner"
    locked_to_project  = "false"
    run_untagged       = "false"
    maximum_timeout    = "3600"
  }

  cache_bucket_prefix = "devaket"
}
