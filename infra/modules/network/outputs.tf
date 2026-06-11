output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnets_compute" {
  value = [aws_subnet.private_3_compute.id, aws_subnet.private_4_compute.id]
}

output "private_subnets_data" {
  value = [aws_subnet.private_5_data.id, aws_subnet.private_6_data.id]
}