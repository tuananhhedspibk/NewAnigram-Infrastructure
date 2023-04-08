data "template_file" "task_definition" {
  template = file("./ecs/task_definition.json")

  vars = {
    account_id        = local.account_id
    region            = local.region
    name              = local.name

    repository_api    = "newanigram"
    api_tag           = "latest"
    log_channel_api   = "newanigram-api"

    log_group_api     = aws_cloudwatch_log_group.this.name
    log_stream_prefix = local.name

    port_api          = local.port_api

    db_host           = var.db_host
    db_username       = var.db_username
    db_password       = var.db_password
    db_database_name  = var.db_database_name
  }
}

resource "aws_ecs_task_definition" "this" {
  family               = "newanigram-api"

  container_definition = data.template_file.task_definition.rendered

  cpu                  = "256"
  memory               = "512"
  network_mode         = "awsvpc"

  task_role_arn        = aws_iam_role.ecs_iam_role.arn
  execution_role_arn   = aws_iam_role.ecs_iam_role.arn
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.https_listener_arn

  action {
    type = "forward"
    target_group_arn = var.lb_target_group_arn
  }

  condition {
    path_pattern {
      value = ["*"]
    }
  }
}

resource "aws_ecs_service" "this" {
  depends_on = [aws_lb_listener_rule.this]

  name = local.name

  desired_count = 1
  launch_type = "EC2"

  cluster = var.cluster_name
  task_definition = aws_ecs_task_definition.this.arn

  network_configuration {
    subnets = var.subnet_ids
    security_groups = [aws_security_group.this.id]
  }

  load_balancer {
    
  }
}

data "aws_iam_policy_document" "ecs_assume_role_policy_document" {
  statement {
    effect        = "Allow"

    principals {
      type        = "Service"
      identifider = ["ecs-tasks.amazonaws.com"]
    }

    actions       = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "ecs_create_log_group_policy_document" {
  statement {
    effect  = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "ssm:GetParameters",
      "secretmanager:GetSecretValue",
      "kms:Decrypt"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_create_log_group_policy" {
  name   = "${var.app_name}_ecs_create_log_group_policy"
  policy = data.aws_iam_policy_document.ecs_create_log_group_policy_document.json
}

resource "aws_iam_role" "ecs_iam_role" {
  name               = "${var.app_name}_ecs_iam_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy_document.json
}

resource "aws_iam_role_policy_attachment" "ecs_iam_role_policy_attachment" {
  role       = aws_iam_role.ecs_iam_role.name
  policy_arn = aws_iam_policy.ecs_create_log_group_policy.arn
}
