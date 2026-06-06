module "eks" {
  source = "./modules/eks"

  cluster_name      = var.eks_cluster_name
  cluster_version   = var.eks_cluster_version
  vpc_id            = var.vpc_id
  subnet_ids        = var.eks_subnet_ids
  vpc_cni_role_name = var.vpc_cni_role_name
  aws_lbc_role_name = var.aws_lbc_role_name
  tags              = var.tags
  region            = var.region
}