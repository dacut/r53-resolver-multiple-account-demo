locals {
    subnetbits = ceil(log(length(data.aws_availability_zones.available.names), 2))
}

resource "aws_vpc" "vpc" {
    cidr_block = var.vpc_cidr_block
    instance_tenancy = "default"
    enable_dns_support = true
    enable_dns_hostnames = true
    assign_generated_ipv6_cidr_block = true
    tags = {
        Name = "${var.tag_prefix}Resolver${var.tag_suffix}"
    }
}

resource "aws_subnet" "subnet" {
    count = length(data.aws_availability_zones.available.names)
    vpc_id = aws_vpc.vpc.id
    cidr_block = cidrsubnet(aws_vpc.vpc.cidr_block, local.subnetbits, count.index)
    ipv6_cidr_block = cidrsubnet(aws_vpc.vpc.ipv6_cidr_block, 8, count.index)
    availability_zone = data.aws_availability_zones.available.names[count.index]
    map_public_ip_on_launch = true
    assign_ipv6_address_on_creation = true
    tags = {
        Name = "${var.tag_prefix}Resolver ${data.aws_availability_zones.available.names[count.index]}${var.tag_suffix}"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "${var.tag_prefix}Resolver${var.tag_suffix}"
    }
}

resource "aws_route" "default_v4" {
    route_table_id = aws_vpc.vpc.main_route_table_id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route" "default_v6" {
    route_table_id = aws_vpc.vpc.main_route_table_id
    destination_ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.igw.id
}

resource "aws_network_interface" "dns" {
    subnet_id = aws_subnet.subnet[0].id
    security_groups = [aws_security_group.dns.id]
    tags = {
        Name = "${var.tag_prefix}On-Prem DNS Emulator${var.tag_suffix}"
    }
}

resource "aws_eip" "dns" {
    vpc = true
    network_interface = aws_network_interface.dns.id
    tags = {
        Name = "${var.tag_prefix}On-Prem DNS Emulator${var.tag_suffix}"
    }
}

output "vpc_id" {
    value = aws_vpc.vpc.id
}

output "zone_id" {
    value = aws_route53_zone.phz.zone_id
}