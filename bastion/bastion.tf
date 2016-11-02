data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user_data.tpl")}"
  vars {
    region            = "${var.region}"
    s3_bucket         = "${var.s3_bucket}"
    s3_bucket_prefix  = "${var.s3_bucket_prefix}"
  }
}

resource "aws_iam_role_policy" "push_logs_policy" {
  name = "push-logs"
  role = "${aws_iam_role.bastion_role.id}"
  policy = "${file("${path.module}/policies/push-logs-policy.json")}"
}

resource "aws_iam_role_policy" "push_cloudwatch_metrics_policy" {
  name = "push-cloudwatch-metrics"
  role = "${aws_iam_role.bastion_role.id}"
  policy = "${file("${path.module}/policies/push-cloudwatch-metrics.json")}"
}

resource "aws_iam_role_policy" "describe_asg_instances_policy" {
  name = "describe-asg-instances"
  role = "${aws_iam_role.bastion_role.id}"
  policy = "${file("${path.module}/policies/describe-asg-instances.json")}"
}

resource "aws_iam_role_policy" "ssh_certificate_storage" {
  name   = "ssh-certificate-storage-${var.s3_bucket_prefix}"
  role   = "${aws_iam_role.bastion_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::${var.s3_bucket}"],
      "Condition": {
          "StringLike": {
              "s3:prefix": "${var.s3_bucket_prefix}/ssh/*"
          }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": ["arn:aws:s3:::${var.s3_bucket}/${var.s3_bucket_prefix}/ssh/*"]
    }
  ]
}
EOF
}

resource "aws_iam_role" "bastion_role" {
  name = "bastion"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "bastion_instance_role" {
  name = "bastion_role"
  path = "/"
  roles = ["bastion"]
  depends_on = ["aws_iam_role.bastion_role"]
}

resource "aws_launch_configuration" "bastion_launch_conf" {
  name_prefix = "bastion-launch-conf-"
  image_id = "${var.ami_id}"
  instance_type = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.bastion_instance_role.id}"
  key_name = "${var.key_name}"
  security_groups = ["${var.security_group_id}"]
  associate_public_ip_address = true
  user_data = "${data.template_file.user_data.rendered}"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "bastion_asg" {
  name = "bastion-asg"
  min_size = "${var.instance_count}"
  max_size = "${var.instance_count}"
  desired_capacity = "${var.instance_count}"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.bastion_launch_conf.name}"
  load_balancers       = [ "${aws_elb.bastion_elb.name}" ]
  termination_policies = [ "OldestInstance" ]
  vpc_zone_identifier = [
    "${var.subnet_primary_id}",
    "${var.subnet_secondary_id}"
  ]
  tag {
    key = "Name"
    value = "bastion-${var.s3_bucket_prefix}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_lifecycle_hook" "launch_pending" {
  name = "auto-scaling-launch-hook"
  heartbeat_timeout = 900
  autoscaling_group_name = "${aws_autoscaling_group.bastion_asg.name}"
  lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
}

resource "aws_autoscaling_schedule" "scale_up" {
  scheduled_action_name  = "scale-up"
  min_size               = "${var.instance_count + 1}"
  max_size               = "${var.instance_count + 1}"
  desired_capacity       = "${var.instance_count + 1}"
  recurrence             = "${var.rolling_update_start}"
  autoscaling_group_name = "${aws_autoscaling_group.bastion_asg.name}"
  count                  = "${signum(length(var.rolling_update_start))}"
  depends_on             = [ "aws_autoscaling_group.bastion_asg" ]
}

resource "aws_autoscaling_schedule" "scale_down" {
  scheduled_action_name  = "scale-down"
  min_size               = "${var.instance_count}"
  max_size               = "${var.instance_count}"
  desired_capacity       = "${var.instance_count}"
  recurrence             = "${var.rolling_update_stop}"
  autoscaling_group_name = "${aws_autoscaling_group.bastion_asg.name}"
  count                  = "${signum(length(var.rolling_update_stop))}"
  depends_on             = [ "aws_autoscaling_group.bastion_asg" ]
}

resource "aws_elb" "bastion_elb" {
  cross_zone_load_balancing = true
  security_groups = ["${var.security_group_id}"]
  idle_timeout = 75
  subnets = [
    "${var.subnet_primary_id}",
    "${var.subnet_secondary_id}"
  ]
  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:22"
    interval            = 15
  }
  lifecycle {
    create_before_destroy = true
  }
}
