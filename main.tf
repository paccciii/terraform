provider "aws" {
  region = "ap-south-1"
}
variable vpc_cidr_blocks {}
variable subnet_cidr_blocks {}
variable availability_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key {}

resource "aws_vpc" "myapp-vpc"{
    cidr_block = var.vpc_cidr_blocks
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

resource "aws_subnet" "myapp-subnet-1"{
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_cidr_blocks
    availability_zone = var.availability_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name: "${var.env_prefix}-igw"
  }
}

/*resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name: "${var.env_prefix}-rtb"
  }
/**/


/*resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id      = aws_subnet.myapp-subnet-1.id
  route_table_id = aws_route_table.myapp-route-table.id
}/**/


resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name = "${var.env_prefix}main-rtb"
  }
}
resource "aws_default_security_group" "default-sg" {
  vpc_id= aws_vpc.myapp-vpc.id

  ingress{
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [var.my_ip]
  }
  ingress{
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress{
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
  egress{
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
  tags = {
    Name : "${var.env_prefix}-sg"
  }
}
data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}


output "aws_ami" {
  value = data.aws_ami.latest-amazon-linux-image.id
}
resource "aws_key_pair" "server-key" {
  key_name   = "server-key"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "TF-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "tfkey"
}


resource "aws_instance" "myapp-server" {
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance_type
  subnet_id   = aws_subnet.myapp-subnet-1.id
  availability_zone = var.availability_zone
  vpc_security_group_ids = [aws_default_security_group.default-sg.id]
  associate_public_ip_address = true
  key_name = aws_key_pair.server-key.id

  tags = {
    Name = "${var.env_prefix}-server"
  }
}
output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}
