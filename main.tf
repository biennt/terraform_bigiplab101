terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}
########################################
variable "availabilty_zone" {
  default = "ap-east-1a"
}
variable "appsrv_names" {
  description = "VM Names"
  default     = ["app1", "app2"]
  type        = set(string)
}
provider "aws" {
  region = "ap-east-1"
}
########################################
resource "aws_vpc" "bienvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name  = "bienvpc"
    Owner = "bien.nguyen@f5.com"
  }
}
resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.bienvpc.id
  tags = {
    Name  = "bieninternetgateway"
    Owner = "bien.nguyen@f5.com"
  }
}
resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.bienvpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}
resource "aws_route_table_association" "route_table_external" {
  subnet_id      = aws_subnet.external.id
  route_table_id = aws_vpc.bienvpc.main_route_table_id
}
resource "aws_route_table_association" "route_table_internal" {
  subnet_id      = aws_subnet.internal.id
  route_table_id = aws_vpc.bienvpc.main_route_table_id
}
########################################
resource "aws_subnet" "management" {
  vpc_id                  = aws_vpc.bienvpc.id
  cidr_block              = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availabilty_zone
  tags = {
    Name  = "bienmanagementsubnet"
    Owner = "bien.nguyen@f5.com"
  }
}
resource "aws_subnet" "external" {
  vpc_id                  = aws_vpc.bienvpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availabilty_zone
  tags = {
    Name  = "bienexternalsubnet"
    Owner = "bien.nguyen@f5.com"
  }
}
resource "aws_subnet" "internal" {
  vpc_id                  = aws_vpc.bienvpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availabilty_zone
  tags = {
    Name  = "bieninternalsubnet"
    Owner = "bien.nguyen@f5.com"
  }
}
########################################
resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Used in the terraform"
  vpc_id      = aws_vpc.bienvpc.id
  tags = {
    Name  = "allowallsecuritygroup"
    Owner = "bien.nguyen@f5.com"
  }
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
########################################
resource "aws_network_interface" "external" {
  subnet_id       = aws_subnet.external.id
  private_ips     = ["10.0.1.10", "10.0.1.100"]
  security_groups = ["${aws_security_group.allow_all.id}"]
  attachment {
    instance     = aws_instance.bigip16.id
    device_index = 1
  }
  tags = {
    Name  = "bienexternalnicbigip16"
    Owner = "bien.nguyen@f5.com"
  }
}
resource "aws_network_interface" "internal" {
  subnet_id       = aws_subnet.internal.id
  private_ips     = ["10.0.2.10", "10.0.2.183"]
  security_groups = ["${aws_security_group.allow_all.id}"]
  attachment {
    instance     = aws_instance.bigip16.id
    device_index = 2
  }
  tags = {
    Name  = "bieninternalnicbigip16"
    Owner = "bien.nguyen@f5.com"
  }
}
########################################
resource "aws_eip" "eip_vip" {
  vpc                       = true
  network_interface         = aws_network_interface.external.id
  associate_with_private_ip = "10.0.1.100"
  tags = {
    Name  = "bieneip4vipbig16"
    Owner = "bien.nguyen@f5.com"
  }
}
########################################
resource "aws_instance" "bigip16" {
  ami                         = "ami-09b7720294469933c"
  instance_type               = "c5.xlarge"
  associate_public_ip_address = true
  private_ip                  = "10.0.0.10"
  availability_zone           = aws_subnet.management.availability_zone
  subnet_id                   = aws_subnet.management.id
  security_groups             = ["${aws_security_group.allow_all.id}"]
  vpc_security_group_ids      = ["${aws_security_group.allow_all.id}"]
  user_data                   = file("userdata_bigip.sh")
  key_name                    = "biennguyen-hk"
  root_block_device { delete_on_termination = true }
  tags = {
    Name  = "bien-bigip16"
    Owner = "bien.nguyen@f5.com"
  }
}

resource "aws_instance" "appsrv" {
  for_each                    = toset(var.appsrv_names)
  ami                         = "ami-0350928fdb53ae439"
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  availability_zone           = aws_subnet.internal.availability_zone
  subnet_id                   = aws_subnet.internal.id
  security_groups             = ["${aws_security_group.allow_all.id}"]
  vpc_security_group_ids      = ["${aws_security_group.allow_all.id}"]
  key_name                    = "biennguyen-hk"
  user_data                   = file("userdata_ubuntu_appsrv.sh")
  root_block_device { delete_on_termination = true }
  tags = {
    Name  = "bien-appsrv"
    Owner = "bien.nguyen@f5.com"
  }
}
########################################
output "bigip16_ip" {
  value       = aws_instance.bigip16.public_ip
  description = "The public IP address of Mgmt"
}
output "bigip16_vip" {
  value       = aws_eip.eip_vip.public_ip
  description = "The public IP address of VIP"
}
output "appsrv_public_ip" {
  value = {
    for k, v in aws_instance.appsrv : k => v.public_ip
  }
}
########################################
output "appsrv_private_ip" {
  value = {
    for k, v in aws_instance.appsrv : k => v.private_ip
  }
}
