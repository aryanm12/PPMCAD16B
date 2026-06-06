variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
}

variable "vpc_id" {
  description = "The AWS region to deploy the resources"
  type        = string
}

variable "eks_subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "eks_cluster_name" {
  description = "Name of the EKS Cluster"
  type        = string
}

variable "eks_cluster_version" {
  description = "Version of the EKS Cluster"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "vpc_cni_role_name" {
  description = "VPC CNI Role Name"
  type        = string
}

variable "aws_lbc_role_name" {
  description = "AWS Load Balancer controller Role Name"
  type        = string
}