terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.63.0"
    }
  }
}

provider "aws" {
  region     = "ap-southeast-1"
  access_key = ""
  secret_key = ""
}

data "aws_vpc" "default" {
  default = true
}

# Default subnets
data "aws_subnet" "subnet_1a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "ap-southeast-1a"
  default_for_az    = true
}

# Create a new subnet in the VPC
resource "aws_subnet" "bastion_subnet_a" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.48.0/20"
  availability_zone = "ap-southeast-1a"
}

resource "aws_subnet" "bastion_subnet_b" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.64.0/20"
  availability_zone = "ap-southeast-1b"
}

resource "aws_route_table" "bastion_rt" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.bastion_subnet_a.id
  route_table_id = aws_route_table.bastion_rt.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.bastion_subnet_b.id
  route_table_id = aws_route_table.bastion_rt.id
}

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
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Create an EC2 instance as a bastion host in the new VPC
resource "aws_instance" "bastion_host" {
  ami                         = "ami-0a72af05d27b49ccb"
  instance_type               = "t2.micro"
  key_name                    = "my_key_pair"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  subnet_id                   = data.aws_subnet.subnet_1a.id
  associate_public_ip_address = true
}

resource "aws_db_subnet_group" "db_subnet_group_1" {
  name        = "db-subnet-group"
  description = "DB subnet group with subnet in ap-southeast-1a and ap-southeast-1b"

  subnet_ids = [
    aws_subnet.bastion_subnet_a.id,
    aws_subnet.bastion_subnet_b.id,
  ]
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "rds_sg"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
}

resource "aws_db_instance" "my_db_instance" {
  identifier             = "my-db-instance"
  engine                 = "postgres"
  engine_version         = "14.6"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group_1.name
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  username               = "postgres"
  password               = "postgres"
  db_name                = "postgres"
  port                   = 5432
  skip_final_snapshot    = true
  multi_az               = false
}

output "aws_instance_public_ip" {
  value = aws_instance.bastion_host.public_ip
}

output "aws_rds" {
  value = aws_db_instance.my_db_instance.address
}
