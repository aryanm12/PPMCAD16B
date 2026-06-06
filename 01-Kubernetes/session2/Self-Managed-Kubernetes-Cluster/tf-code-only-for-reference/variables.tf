variable "region" {
  description = "The AWS region to deploy the resources"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster."
  type        = list(string)
}

variable "ami_id" {
  description = "Ubuntu AMI ID"
  type        = string
}

variable "node_type" {
  description = "EC2 Node Type for Kubernetes master and worker nodes"
  type        = string
}

variable "key_pair" {
  description = "AWS Key Pair to be associated with the EC2 server"
  type        = string
}