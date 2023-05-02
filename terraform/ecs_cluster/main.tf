variable app_name {
  type = string
}

resource "aws_ecs_cluster" "this" {
  name = "${var.app_name}"
}

output cluster_name {
  value = aws_ecs_cluster.this.name
}
