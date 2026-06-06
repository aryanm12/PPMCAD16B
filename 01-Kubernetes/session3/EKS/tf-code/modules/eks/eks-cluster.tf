# FETCH OIDC PROVIDER THUMBPRINT FOR ROOT CA AND CREATE OPENID CONNECT PROVIDER

data "aws_caller_identity" "current" {}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}


resource "aws_eks_cluster" "this" {
  name    = var.cluster_name
  version = var.cluster_version

  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = false
    endpoint_public_access  = true
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }
  
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.AmazonEKSClusterPolicy]
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng-01"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 2
  }

  instance_types = ["t3.medium"]  # Replace with your desired instance type

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  ]
}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "vpc-cni"
  service_account_role_arn = aws_iam_role.vpc_cni.arn
  depends_on               = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "coredns"
  depends_on    = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name  = aws_eks_cluster.this.name
  addon_name    = "kube-proxy"
  depends_on    = [aws_eks_node_group.main]
}

resource "aws_ec2_tag" "subnet_for_aws_lbc" {
  for_each    = toset(var.subnet_ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}