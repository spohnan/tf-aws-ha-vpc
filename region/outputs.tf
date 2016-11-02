output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "internal_security_group_id" {
  value = "${aws_security_group.internal-all.id}"
}

output "public_primary_subnet_id" {
  value = "${module.public_primary_subnet.subnet_id}"
}

output "public_primary_subnet_az" {
  value = "${module.public_primary_subnet.availability_zone}"
}

output "public_secondary_subnet_id" {
  value = "${module.public_primary_subnet.subnet_id}"
}

output "public_secondary_subnet_az" {
  value = "${module.public_secondary_subnet.availability_zone}"
}

output "private_primary_subnet_id" {
  value = "${module.private_primary_subnet.subnet_id}"
}

output "private_primary_subnet_az" {
  value = "${module.private_primary_subnet.availability_zone}"
}

output "private_secondary_subnet_id" {
  value = "${module.private_primary_subnet.subnet_id}"
}

output "private_secondary_subnet_az" {
  value = "${module.private_secondary_subnet.availability_zone}"
}