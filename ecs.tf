resource "aws_ecs_cluster" "main" {
  name = "accelerator-${var.env}-cluster"
}

data "template_file" "accelerator_app" {
  template = "${file("templates/ecs/cb_app.json.tpl")}"

  vars {
    app_image      = "${var.app_image}"
    fargate_cpu    = "${var.fargate_cpu}"
    fargate_memory = "${var.fargate_memory}"
    aws_region     = "${var.aws_region}"
    app_port       = "${var.app_port}"
  }
}

resource "aws_ecs_task_definition" "app" {
  family                   = "accelerator-${var.env}-app-task"
  execution_role_arn       = "${var.ecs_task_execution_role}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "${var.fargate_cpu}"
  memory                   = "${var.fargate_memory}"
  container_definitions    = "${data.template_file.accelerator_app.rendered}"
}

resource "aws_ecs_service" "main" {
  name            = "accelerator-${var.env}-service"
  cluster         = "${aws_ecs_cluster.main.id}"
  task_definition = "${aws_ecs_task_definition.app.arn}"
  desired_count   = "${var.app_count}"
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = ["${aws_security_group.ecs_tasks.id}"]
    subnets          = ["${aws_subnet.private.*.id}"]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.app.id}"
    container_name   = "accelerator-${var.env}-app"
    container_port   = "${var.app_port}"
  }

  depends_on = [
    "aws_alb_listener.front_end",
  ]
}
