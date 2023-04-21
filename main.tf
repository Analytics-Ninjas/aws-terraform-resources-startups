terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.64.0"
    }
  }
}

provider "aws" {
  region     = "ap-northeast-1"
  access_key = ""
  secret_key = ""
}

# VPC
data "aws_vpc" "default" {
  default = true
}

# Default subnets
data "aws_subnet" "subnet_1a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "ap-northeast-1a"
  default_for_az    = true
}

# Create a new subnet in the VPC
resource "aws_subnet" "bastion_subnet_a" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.48.0/20"
  availability_zone = "ap-northeast-1a"
}

resource "aws_subnet" "bastion_subnet_d" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.64.0/20"
  availability_zone = "ap-northeast-1d"
}

# Route Table
resource "aws_route_table" "bastion_rt" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.bastion_subnet_a.id
  route_table_id = aws_route_table.bastion_rt.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.bastion_subnet_d.id
  route_table_id = aws_route_table.bastion_rt.id
}

# Security Group
resource "aws_security_group" "bastion_sg" {
  name_prefix = "bastion-sg-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Keys
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "my_key_pair" # Create "myKey" to AWS!!
  public_key = tls_private_key.pk.public_key_openssh

  provisioner "local-exec" { # Create "myKey.pem" to your computer!!
    command = "echo '${tls_private_key.pk.private_key_pem}' > ./my_key_pair.pem"
  }
}

# Create an EC2 instance as a bastion host in the new VPC
resource "aws_instance" "bastion_host" {
  ami                         = "ami-0d979355d03fa2522"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.kp.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  subnet_id                   = data.aws_subnet.subnet_1a.id
  associate_public_ip_address = true
}

# AWS RDS
resource "aws_db_subnet_group" "db_subnet_group_1" {
  name        = "db-subnet-group"
  description = "DB subnet group with subnet in ap-southeast-1a and ap-southeast-1d"

  subnet_ids = [
    aws_subnet.bastion_subnet_a.id,
    aws_subnet.bastion_subnet_d.id,
  ]
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "rds_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
}

resource "aws_db_instance" "my_db_instance" {
  identifier             = "my-db-instance"
  engine                 = "mysql"
  engine_version         = "8.0.32"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group_1.name
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  username               = "admin"
  password               = "password"
  db_name                = "stock_db"
  port                   = 3306
  skip_final_snapshot    = true
  multi_az               = false
}

# S3
resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "analytics-ninjas-${random_string.bucket_suffix.result}"
}

# Output
output "aws_instance_public_ip" {
  value = aws_instance.bastion_host.public_ip
}

output "aws_rds" {
  value = aws_db_instance.my_db_instance.address
}

output "aws_s3_bucket_name" {
  value = aws_s3_bucket.s3_bucket.bucket
}
