output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.my_public_subnet.id
}

output "ec2_private_ip" {
  value = aws_instance.my_ec2.private_ip
}

output "ec2_public_ip" {
  value = aws_instance.my_ec2.public_ip
}