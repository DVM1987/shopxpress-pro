output "vpc_id" {
  description = "VPC ID, consumed by EKS / RDS / endpoint sub-components"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block, used in security group rules"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (3 AZs), used by ALB internet-facing"
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "Private-app subnet IDs (3 AZs), used by EKS Managed Node Group"
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "Private-data subnet IDs (3 AZs), used by RDS / Redis subnet group"
  value       = aws_subnet.private_data[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID (single zonal NAT in public-1a, lab cost-saving)"
  value       = aws_nat_gateway.main.id
}

output "azs" {
  description = "Availability Zones list"
  value       = var.azs
}
