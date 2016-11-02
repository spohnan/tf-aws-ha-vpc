
resource "aws_subnet" "main" {
  cidr_block = "${cidrsubnet(data.aws_vpc.target.cidr_block, 4, var.subnet_offset)}"
  vpc_id     = "${var.vpc_id}"
  map_public_ip_on_launch = "${var.map_public_ip_on_launch}"
  availability_zone = "${var.availability_zone}"
  tags {
    Name = "${var.subnet_name}"
  }
}
