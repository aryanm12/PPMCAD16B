module "Kubernetes" {
  source = "./modules/Kubernetes"

  subnet_ids = var.subnet_ids
  ami_id     = var.ami_id
  node_type  = var.node_type
  key_pair   = var.key_pair
  tags       = var.tags
  region     = var.region
}