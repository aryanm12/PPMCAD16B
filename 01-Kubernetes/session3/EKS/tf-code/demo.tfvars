tags = {
  Environment = "demo"
  Owner       = "Aryan"
}
region              = "ap-southeast-1"
vpc_id              = "vpc-0a5d0b90e978dd78d"
eks_subnet_ids      = ["subnet-01ed811e6bd6d7965", "subnet-06a7c8dbffd15e868"]
eks_cluster_name    = "demo-01"
vpc_cni_role_name   = "AmazonEKSVPCCNIRole-demo-01"
eks_cluster_version = "1.35"
aws_lbc_role_name   = "aws-lbc-demo-01"