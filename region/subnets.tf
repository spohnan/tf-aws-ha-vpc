data "aws_availability_zones" "all" { }

// -------------------------
// Primary Public Subnet

resource "aws_eip" "ngw-ip-1" {
  vpc = true
}

module "public_primary_subnet" "main" {
  source            = "../subnet"
  subnet_name       = "public-${data.aws_availability_zones.all.names[0]}"
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "${data.aws_availability_zones.all.names[0]}"
  map_public_ip_on_launch = true
  subnet_offset     = 0
}

resource "aws_nat_gateway" "primary" {
  allocation_id = "${aws_eip.ngw-ip-1.id}"
  subnet_id = "${module.public_primary_subnet.subnet_id}"
  depends_on = ["aws_internet_gateway.main", "aws_eip.ngw-ip-1"]
}

resource "aws_route_table" "public_primary_route_table" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }
}

resource "aws_route_table_association" "pub_primary_route_assoc" {
  subnet_id      = "${module.public_primary_subnet.subnet_id }"
  route_table_id = "${aws_route_table.public_primary_route_table.id}"
}

// -------------------------
// Secondary Public Subnet

resource "aws_eip" "ngw-ip-2" {
  vpc = true
}

module "public_secondary_subnet" {
  source            = "../subnet"
  subnet_name       = "public-${data.aws_availability_zones.all.names[1]}"
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "${data.aws_availability_zones.all.names[1]}"
  map_public_ip_on_launch = true
  subnet_offset     = 1
}

resource "aws_nat_gateway" "secondary" {
  allocation_id = "${aws_eip.ngw-ip-2.id}"
  subnet_id = "${module.public_secondary_subnet.subnet_id}"
  depends_on = ["aws_internet_gateway.main", "aws_eip.ngw-ip-2"]
}

resource "aws_route_table" "public_secondary_route_table" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.main.id}"
  }
}

resource "aws_route_table_association" "pub_secondary_route_assoc" {
  subnet_id      = "${module.public_secondary_subnet.subnet_id }"
  route_table_id = "${aws_route_table.public_secondary_route_table.id}"
}

// -------------------------
// Primary Private Subnet

module "private_primary_subnet" {
  source            = "../subnet"
  subnet_name       = "private-${data.aws_availability_zones.all.names[0]}"
  vpc_id            = "${aws_vpc.main.id}"
  availability_zone = "${data.aws_availability_zones.all.names[0]}"
  subnet_offset     = 2
}

resource "aws_route_table" "private_primary_route_table" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.primary.id}"
  }
}

resource "aws_route_table_association" "private_primary_route_assoc" {
  subnet_id      = "${module.private_primary_subnet.subnet_id }"
  route_table_id = "${aws_route_table.private_primary_route_table.id}"
}

// -------------------------
// Secondary Private Subnet

module "private_secondary_subnet" {
  source = "../subnet"
  subnet_name = "private-${data.aws_availability_zones.all.names[1]}"
  vpc_id = "${aws_vpc.main.id}"
  availability_zone = "${data.aws_availability_zones.all.names[1]}"
  subnet_offset = 3
}

resource "aws_route_table" "private_secondary_route_table" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.secondary.id}"
  }
}

resource "aws_route_table_association" "private_secondary_route_assoc" {
  subnet_id      = "${module.private_secondary_subnet.subnet_id }"
  route_table_id = "${aws_route_table.private_secondary_route_table.id}"
}

// -------------------------
// S3 Endpoint attached to private subnets

resource "aws_vpc_endpoint" "private-s3" {
  vpc_id = "${aws_vpc.main.id}"
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = [
    "${aws_route_table.private_primary_route_table.id}",
    "${aws_route_table.private_secondary_route_table.id}"
  ]
}
