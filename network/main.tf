variable region {
  type = string
}

variable app_name {
  type = string
}

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

resource "aws_route_table" "private_rt" {

}

resource "aws_route_table" "public_rt" {
  
}
