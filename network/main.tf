variable region {
  type = string
}

variable app_name {
  type = string
}

variable public_subnets_cidr {
  type = list
}

variable private_subnets_cidr {
  type = list
}

locals {
  alb_ports_in = [
    443,
    80
  ]
}

// Define VPC, Subnets, Internet gateway, Route table, ...

resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags   = {
    Name = "${var.app_name}-vpc"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = {
    Name = "${var.app_name}-igw"
  }
}

// ElasticIP for NAT gateway
resource "aws_eip" "nat_eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.id]
}

// NAT gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)

  tags = {
    Name = "${var.app_name}-nat"
  }
}

// Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id

  cidr_block              = element(var.public_subnets_cidr, count.index)

  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-subnet"
  }
}

// Private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  
  cidr_block              = element(var.private_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.app_name}-private-subnet"
  }
}

// Private route table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.app_name}-private-route-table"
  }
}

// Public route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.app_name}-public-route-table"
  }
}

// Route for internet gateway
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

// Route for NAT
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private_rt.id
}

// Default Security group of VPC
resource "aws_security_group" "default" {
  name       = "${var.app_name}-vpc-default-sg"
  vpc_id     = aws_vpc.main_vpc.id
  depends_on = [
    aws_vpc.main_vpc
  ]

  ingress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    self      = true
  }
}

// Define alb

resource "aws_security_group" "alb_security_group" {
  name = "${var.app_name}-alb-security-group"
  vpc_id = aws_vpc.main_vpc.id

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1" // Allow all protocols
  }

  dynamic "ingress" {
    for_each = toset(local.ports_in)
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_lb" "alb" {
  name = "${var.app_name}-alb"
  load_balancer_type = "application"
  idle_timeout = 180

  security_group = [aws_security_group.alb.id]
}

output {
  vpc_id   = aws_vpc.main_vpc.id
  vpc_cidr = aws_vpc.main_vpc.cidr_block
}
