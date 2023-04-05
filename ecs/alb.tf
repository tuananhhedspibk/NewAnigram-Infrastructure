variable alb_name {
  type = string
}

variable vpc_id {
  type = string
}

variable deregistration_delay {
  type = string
}

variable health_check_path {
  type = string
}

variable public_subnet_ids {
  type = list(string)
}

variable allow_cidr_block {
  type = string
}

resource "aws_alb_target_group" "default" {
  name                 = "${var.alb_name}-default"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = var.deregistration_delay

  health_check {
    path     = var.health_check_path
    protocol = "HTTP"
  }
}

resource "aws_alb" "alb" {
  name           = var.alb_name
  subnets        = var.public_subnet_ids
  security_group = ["${aws_security_group.alb.id}"]
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.default.arn
    type             = "forward"
  }
}

resource "aws_security_group" "alb" {
  name   = "${var.alb_name}-alb"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "https_from_anywhere" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "TCP"
  cidr_blocks       = var.allow_cidr_block
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "outbound_internet_access" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}
