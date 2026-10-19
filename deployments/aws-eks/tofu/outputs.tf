output "cluster_name" {
  value = module.eks.cluster_name
}

output "region" {
  value = var.region
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cilium_operator_role_arn" {
  value = aws_iam_role.cilium_operator.arn
}

output "update_kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "estimated_monthly_cost_usd" {
  description = "Rough default-region estimate for the default sizes; check the AWS pricing page before applying."
  value = {
    eks_control_plane = 73.00
    worker_nodes      = 60.74
    nat_gateway       = 32.85
    ebs_gp3           = 3.20
    total             = 169.79
  }
}
