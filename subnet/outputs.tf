output "subnet_id" {
  value = "${aws_subnet.main.id}"
}

output "availability_zone" {
  value = "${aws_subnet.main.availability_zone}"
}
