variable app_name {
  type = string
}

variable vpc_cidr {
  type = string
}

variable availability_zones {
  type = list(string)
}

variable public_subnets_cidr {
  type = list(string)
}

variable private_subnets_cidr {
  type = list(string)
}

variable target_health_check_port {
  type = number
}

variable target_health_check_path {
  type = string
}

locals {
  alb_ports_in = [ 443, 80 ]
}

// Define VPC, Subnets, Internet gateway, Route table, ...

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags   = {
    Name = "${var.app_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = {
    Name = "${var.app_name}-igw"
  }
}

// ElasticIP for NAT gateway
resource "aws_eip" "nat" {
  vpc        = true
  depends_on = [aws_internet_gateway.main]
}

// NAT gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = element(aws_subnet.public.*.id, 0)

  tags = {
    Name = "${var.app_name}-nat"
  }
}

// Public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id

  count                   = length(var.public_subnets_cidr)
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.app_name}-public-subnet-${element(var.availability_zones, count.index)}"
  }
}

// Private subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  
  count                   = length(var.private_subnets_cidr)
  cidr_block              = element(var.private_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.app_name}-private-subnet-${element(var.availability_zones, count.index)}"
  }
}

// Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-private-route-table"
  }
}

// Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.app_name}-public-route-table"
  }
}

// Route for public route table
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

// Route for private rotue table
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

// Define ALB
resource "aws_security_group" "alb" {
  name = "${var.app_name}-alb-sg"
  vpc_id = aws_vpc.main.id

  // Outbound rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" // Allow all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Inbound rules
  dynamic "ingress" {
    for_each = toset(local.alb_ports_in)
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_lb" "main" {
  name               = "${var.app_name}-alb"
  load_balancer_type = "application"
  idle_timeout       = 180

  subnets            = aws_subnet.public.*.id

  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "main" {
  name = "${var.app_name}-alb-main-tg"
  vpc_id = aws_vpc.main.id

  port = 80
  protocol = "HTTP"
  target_type = "ip"

  health_check {
    port = var.target_health_check_port
    path = var.target_health_check_path
  }
}

resource "aws_lb_listener" "main" {
  port               = 80
  protocol           = "HTTP"
  load_balancer_arn  = aws_lb.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.id
  }
}

resource "aws_lb_listener_rule" "main" {
  listener_arn = aws_lb_listener.main.arn

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.main.id
  }

  condition {
    query_string {
      value = "*"
    }
  }
}

output public_subnet_ids {
  value = aws_subnet.public.*.id
}

output private_subnet_ids {
  value = aws_subnet.private.*.id
}

output vpc_id {
  value = aws_vpc.main.id
}

output lb_target_group_arn {
  value = aws_lb_target_group.main.arn
}

output http_listener_arn {
  value = aws_lb_listener.main.arn
}
