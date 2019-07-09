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
        Name = "${var.tag_prefix}User${var.tag_suffix}"
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
        Name = "${var.tag_prefix}User ${data.aws_availability_zones.available.names[count.index]}${var.tag_suffix}"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "${var.tag_prefix}User${var.tag_suffix}"
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

resource "aws_security_group_rule" "ssh" {
    type = "ingress"
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_group_id = aws_vpc.vpc.default_security_group_id
    description = "SSH from anywhere"
}

resource "aws_security_group_rule" "icmpv4" {
    type = "ingress"
    protocol = "icmp"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_group_id = aws_vpc.vpc.default_security_group_id
    description = "ICMPv4 from anywhere"
}

resource "aws_security_group_rule" "icmpv6" {
    type = "ingress"
    protocol = "icmpv6"
    from_port = -1
    to_port = -1
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_group_id = aws_vpc.vpc.default_security_group_id
    description = "ICMPv6 from anywhere"
}

resource "aws_instance" "lookup" {
    ami = data.aws_ami.amzn2.id
    instance_type = var.lookup_instance_type
    key_name = var.keypair
    monitoring = false
    vpc_security_group_ids = [aws_vpc.vpc.default_security_group_id]
    subnet_id = aws_subnet.subnet[0].id
    associate_public_ip_address = true
    ipv6_address_count = 1
    tags = {
        Name = "${var.tag_prefix}DNS Lookup Test${var.tag_suffix}"
    }
    user_data = file("${path.module}/instance_init.sh")
    volume_tags = {
        Name = "${var.tag_prefix}DNS Lookup Test${var.tag_suffix}"
    }
    root_block_device {
        volume_type = "gp2"
        volume_size = 8
        delete_on_termination = true
    }
}

output "vpc_id" {
    value = aws_vpc.vpc.id
}

output "lookup_ipv4_address" {
    value = aws_instance.lookup.public_ip
}

output "lookup_ipv6_address" {
    value = join(" ", aws_instance.lookup.ipv6_addresses)
}