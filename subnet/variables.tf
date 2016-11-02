variable "vpc_id" {}

variable "availability_zone" {}

variable "subnet_offset" {}

variable "subnet_name" {
  default = ""
}

variable "map_public_ip_on_launch" {
  default = false
}

data "aws_availability_zone" "target" {
  name = "${var.availability_zone}"
}

data "aws_vpc" "target" {
  id = "${var.vpc_id}"
}
