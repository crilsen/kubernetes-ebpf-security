# IRSA role for cilium-operator so AWS ENI IPAM can create and attach ENIs.
data "aws_iam_policy_document" "cilium_operator_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cilium-operator"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cilium_operator" {
  name               = "${var.cluster_name}-cilium-operator"
  description        = "IRSA role for the Cilium operator (ENI IPAM) in the eBPF security lab"
  assume_role_policy = data.aws_iam_policy_document.cilium_operator_assume.json

  tags = local.tags
}

data "aws_iam_policy_document" "cilium_operator" {
  statement {
    sid    = "ENIIPAMRead"
    effect = "Allow"
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ENIIPAMWrite"
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:AttachNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cilium_operator" {
  name        = "${var.cluster_name}-cilium-operator"
  description = "Permissions required by the Cilium operator for AWS ENI IPAM"
  policy      = data.aws_iam_policy_document.cilium_operator.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cilium_operator" {
  role       = aws_iam_role.cilium_operator.name
  policy_arn = aws_iam_policy.cilium_operator.arn
}
