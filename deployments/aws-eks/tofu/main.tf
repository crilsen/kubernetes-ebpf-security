locals {
  tags = merge(var.tags, {
    Environment = var.cluster_name
  })

  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  public_subnets  = [cidrsubnet(var.vpc_cidr, 4, 2), cidrsubnet(var.vpc_cidr, 4, 3)]

  enable_nat_gateway = true
  # Single NAT gateway keeps the demo cheap; it is also a single point of failure.
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  endpoint_public_access                   = true
  enable_irsa                              = true
  enable_cluster_creator_admin_permissions = true

  # Module v21 hardcodes bootstrap_self_managed_addons = false and installs only
  # the addons listed below. Cilium is the primary CNI and replaces kube-proxy;
  # CoreDNS is installed after Cilium by scripts/eks-up.sh.
  addons = {}

  eks_managed_node_groups = {
    lab = {
      name           = "lab"
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      labels = {
        role = "lab"
      }
    }
  }

  tags = local.tags
}
