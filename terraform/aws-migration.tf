# AWS Migration Infrastructure
# Creates target infrastructure for on-premise to cloud migration

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# VPC for migration
resource "aws_vpc" "migration" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "migration-vpc"
    Purpose = "on-premise-migration"
  }
}

# VPN Gateway for on-premise connectivity
resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.migration.id

  tags = {
    Name = "migration-vpn-gateway"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "migration-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "migration-db-subnet-group"
  }
}

# RDS Instance (target for database migration)
resource "aws_db_instance" "migration" {
  identifier             = "migration-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.medium"
  allocated_storage      = 100
  storage_encrypted       = true
  db_name                = "app_db"
  username               = "admin"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  backup_retention_period = 7
  skip_final_snapshot    = false
  final_snapshot_identifier = "migration-db-final-snapshot"

  tags = {
    Name = "migration-database"
  }
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "migration-rds-sg"
  description = "Security group for RDS migration"
  vpc_id      = aws_vpc.migration.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "migration-rds-sg"
  }
}

# Subnets
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.migration.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "migration-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.migration.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "migration-private-${count.index + 1}"
  }
}

