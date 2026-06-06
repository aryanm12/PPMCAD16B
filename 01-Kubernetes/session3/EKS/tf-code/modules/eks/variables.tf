variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "The version of the EKS cluster."
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "The AWS region to deploy the resources"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster."
  type        = list(string)
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