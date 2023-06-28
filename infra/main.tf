terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# create a vpc
resource "aws_vpc" "k8s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "k8s_vpc"
  }
}

# create a subnet
resource "aws_subnet" "k8s_subnet" {
  vpc_id            = aws_vpc.k8s_vpc.id
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.1.0/24"
  tags = {
    Name = "k8s-subnet"
  }
}

# Create a Internet_Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "k8s-gw"
  }
}

# Create a Route_table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }
}

# Associate subnet with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.k8s_subnet.id
  route_table_id = aws_route_table.rt.id
}

# create a Security Group for kubernetes controller 
resource "aws_security_group" "controller_SG" {
  name        = "Controller_SG"
  description = "Allow inbound traffic for kubernetes controller"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  ingress {
    description      = "Kubernetes API server"
    from_port        = 6443
    to_port          = 6443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "ETCD server client API"
    from_port        = 2379
    to_port          = 2380
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "Kubelet API"
    from_port        = 10250
    to_port          = 10250
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "kube-scheduler"
    from_port        = 10259
    to_port          = 10259
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "kube-controller-manager"
    from_port        = 10257
    to_port          = 10257
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "k8s_Controller_SG"
  }
}

# create a Security Groupr for kubernetes worker
resource "aws_security_group" "worker_SG" {
  name        = "worker_SG"
  description = "Allow inbound traffic for kubernetes worker nodes"
  vpc_id      = aws_vpc.k8s_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "Kubelet API"
    from_port        = 10250
    to_port          = 10250
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "nodeport services"
    from_port        = 30000
    to_port          = 32767
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "k8s_worker_SG"
  }
}

# create a IAM role
resource "aws_iam_role" "role" {
  name = "my-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


# attach a policy to the role
resource "aws_iam_role_policy_attachment" "role_policy_attachment" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# creating iam_instance_profile
resource "aws_iam_instance_profile" "instance_profile" {
  name = "my-instance-profile"
  role = aws_iam_role.role.name
}

# create aws key pair
resource "aws_key_pair" "k8s-key" {
  key_name   = "k8s-key"
  public_key = tls_private_key.rsa-4096-example.public_key_openssh
}

# create a private key in aws
resource "tls_private_key" "rsa-4096-example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# save pem file to local host
resource "local_file" "private-key" {
  content  = tls_private_key.rsa-4096-example.private_key_pem
  filename = "k8s-key.pem"
}

# creat a kubernetes controller
resource "aws_instance" "kubernetes_controller" {
  ami                         = "ami-08c40ec9ead489470"
  instance_type               = "t2.medium"
  availability_zone           = "us-east-1a"
  key_name                    = "k8s-key"
  security_groups             = [aws_security_group.controller_SG.id]
  subnet_id                   = aws_subnet.k8s_subnet.id
  associate_public_ip_address = true
  user_data                   = file("./Controller1.sh")
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  depends_on = [
    aws_key_pair.k8s-key
  ]

  tags = {
    "Name" = "k8s-controller"
  }
}

# creat a kubernetes worker nodes
resource "aws_instance" "kubernetes_workers" {
  ami                         = "ami-08c40ec9ead489470"
  instance_type               = "t3.medium"
  availability_zone           = "us-east-1a"
  key_name                    = "k8s-key"
  security_groups             = [aws_security_group.worker_SG.id]
  subnet_id                   = aws_subnet.k8s_subnet.id
  associate_public_ip_address = true
  for_each                    = toset(["k8s-worker1", "k8s-worker2"])
  user_data                   = file("./worker.sh")
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  depends_on = [
    aws_key_pair.k8s-key
  ]
  tags = {
    "Name" = each.key
  }
}

# save ip-address to local host
resource "local_file" "controller-ip" {
  content  = aws_instance.kubernetes_controller.public_ip
  filename = "controller-ip.txt"
}

# save ip-addresses to local host
resource "local_file" "worker-ip" {
  content  = join("\n", [for instance in aws_instance.kubernetes_workers : instance.public_ip])
  filename = "workers-ip.txt"
}
