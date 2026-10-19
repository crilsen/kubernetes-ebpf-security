variable "region" {
  description = "AWS region for the lab. Keep it explicit to make cost and blast radius obvious."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name. Also used as the environment tag."
  type        = string
  default     = "ebpf-lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.cluster_name))
    error_message = "cluster_name must be lowercase alphanumeric with dashes, 3-31 characters."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for EKS. Cilium support must be confirmed for this version before apply."
  type        = string
  default     = "1.35"
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node group."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3
}

variable "vpc_cidr" {
  description = "CIDR for the lab VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "tags" {
  description = "Extra tags applied to every resource."
  type        = map(string)
  default = {
    Project   = "kubernetes-ebpf-security-lab"
    ManagedBy = "terraform"
    Purpose   = "demo"
  }
}
