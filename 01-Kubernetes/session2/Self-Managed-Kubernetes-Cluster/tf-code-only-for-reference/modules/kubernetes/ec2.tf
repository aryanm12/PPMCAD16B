resource "aws_instance" "master" {
  ami                    = var.ami_id
  instance_type          = var.node_type
  key_name               = var.key_pair
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.kubernetes_sg.id]

  tags = merge(
    var.tags,
    {
      Name = "k8s-master"
    }
  )
}

resource "aws_instance" "workers" {
  count                  = 2
  ami                    = var.ami_id
  instance_type          = var.node_type
  key_name               = var.key_pair
  subnet_id              = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.kubernetes_sg.id]

  tags = merge(
    var.tags,
    {
      Name = "k8s-worker-${count.index + 1}"
    }
  )
}