# Network

## Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "my-vpc"
  }
}

## Get availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

## Create internet gateway
resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-internet-gateway"
  }
}

## Create public subnet
resource "aws_subnet" "my_public_subnet" {
  vpc_id = aws_vpc.my_vpc.id

  count = 2

  cidr_block = cidrsubnet(var.vpc_cidr, 3, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "my-public-subnet"
  }
}

## Create route table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  }

  tags = {
    Name = "my-route-table"
  }
}

## Create route table association
resource "aws_route_table_association" "my_route_table_association" {
  count = 2

  subnet_id      = aws_subnet.my_public_subnet[count.index].id
  route_table_id = aws_route_table.my_route_table.id
}

# Compute

## Create security group
resource "aws_security_group" "my_security_group_ec2" {
  name_prefix = "my-security-group-ec2"
  vpc_id      = aws_vpc.my_vpc.id

  tags = {
    Name = "my-security-group-ec2"
  }
}
## Create security group rules
resource "aws_security_group_rule" "my_rule_ec2_allow_ssh" {
  security_group_id = aws_security_group.my_security_group_ec2.id

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  type        = "ingress"
}

resource "aws_security_group_rule" "egress_ec2_all" {
  security_group_id = aws_security_group.my_security_group_ec2.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  type        = "egress"
}

## Get ami id
data "aws_ami" "debian" {
  most_recent = true
  filter {
    name   = "name"
    values = ["debian-stretch-hvm-x86_64-gp2*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["379101102735"] # Debian Project
}

## Create public key
resource "aws_key_pair" "my_public_key" {
  key_name   = "my-public-key"
  public_key = file("id_rsa.pub")
}

## Create EC2
resource "aws_instance" "my_ec2" {
  ami                         = data.aws_ami.debian.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.my_public_subnet[0].id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.my_public_key.id

  vpc_security_group_ids = [
    "${aws_security_group.my_security_group_ec2.id}"
  ]

  tags = {
    Name = "my-ec2"
  }
}

## RDS

## Create db subnet group
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = aws_subnet.my_public_subnet.*.id

  tags = {
    Name = "my-db-subnet-group"
  }
}

## Create security group
resource "aws_security_group" "my_security_group_db" {
  name_prefix = "my-security-group-db"
  vpc_id      = aws_vpc.my_vpc.id

  tags = {
    Name = "my-security-group-db"
  }
}
## Create security group rules
resource "aws_security_group_rule" "my_rule_allow_3306" {
  security_group_id = aws_security_group.my_security_group_db.id

  from_port   = 3306
  to_port     = 3306
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  type        = "ingress"
}

resource "aws_security_group_rule" "egress_db_all" {
  security_group_id = aws_security_group.my_security_group_db.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  type        = "egress"
}

resource "aws_db_instance" "my_db" {
  identifier = "my-db"

  allocated_storage = 10
  storage_type      = "gp2"
  engine            = "mysql"
  engine_version    = "5.7"
  instance_class    = "db.t2.micro"

  name                 = "mydb"
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql5.7"

  skip_final_snapshot = true

  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids = list(aws_security_group.my_security_group_db.id)
}