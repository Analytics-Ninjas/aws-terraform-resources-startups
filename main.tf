terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.63.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1"
  access_key = ""
  secret_key = ""
}

# Create a new VPC
resource "aws_vpc" "bastion_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bastion-vpc"
  }
}

# Create a new subnet in the VPC
resource "aws_subnet" "bastion_subnet" {
  vpc_id     = aws_vpc.bastion_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "bastion-subnet"
  }
}

# Create a security group for the bastion host that allows incoming traffic on port 22 from anywhere
resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-sg-"
  vpc_id      = aws_vpc.bastion_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "bastion_igw" {
  vpc_id = aws_vpc.bastion_vpc.id

  tags = {
    Name = "bastion-igw"
  }
}

# Create a Route Table for the VPC
resource "aws_route_table" "bastion_rt" {
  vpc_id = aws_vpc.bastion_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bastion_igw.id
  }

  tags = {
    Name = "bastion-rt"
  }
}

# Associate the Route Table with the subnet
resource "aws_route_table_association" "bastion_rta" {
  subnet_id      = aws_subnet.bastion_subnet.id
  route_table_id = aws_route_table.bastion_rt.id
}

# Create an EC2 instance as a bastion host in the new VPC
resource "aws_instance" "bastion_host" {
  ami           = "ami-0a72af05d27b49ccb"
  instance_type = "t2.micro"
  key_name      = "my_key_pair"
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  subnet_id     = aws_subnet.bastion_subnet.id
  associate_public_ip_address = true
}

# Allocate an Elastic IP address for the bastion host
resource "aws_eip" "bastion_eip" {
  vpc = true
}

# Associate the Elastic IP address with the bastion host
resource "aws_eip_association" "bastion_eip_assoc" {
  instance_id   = aws_instance.bastion_host.id
  allocation_id = aws_eip.bastion_eip.id
}
