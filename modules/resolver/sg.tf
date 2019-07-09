resource "aws_security_group" "dns" {
    name = "DNS Server"
    description = "Allow DNS services"
    vpc_id = aws_vpc.vpc.id
    revoke_rules_on_delete = true

    tags = {
        Name = "${var.tag_prefix}DNS Server${var.tag_suffix}"
    }
}

resource "aws_security_group_rule" "ssh" {
    type = "ingress"
    protocol = "tcp"
    from_port = 22
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_group_id = aws_security_group.dns.id
    description = "SSH from anywhere"
}

resource "aws_security_group_rule" "icmpv4" {
    type = "ingress"
    protocol = "icmp"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_group_id = aws_security_group.dns.id
    description = "ICMPv4 from anywhere"
}

resource "aws_security_group_rule" "icmpv6" {
    type = "ingress"
    protocol = "icmpv6"
    from_port = -1
    to_port = -1
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_group_id = aws_security_group.dns.id
    description = "ICMPv6 from anywhere"
}

resource "aws_security_group_rule" "dns_udp" {
    type = "ingress"
    protocol = "udp"
    from_port = 53
    to_port = 53
    cidr_blocks = [aws_vpc.vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
    security_group_id = aws_security_group.dns.id
    description = "DNS UDP intra-VPC"
}

resource "aws_security_group_rule" "dns_tcp" {
    type = "ingress"
    protocol = "tcp"
    from_port = 53
    to_port = 53
    cidr_blocks = [aws_vpc.vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
    security_group_id = aws_security_group.dns.id
    description = "DNS TCP intra-VPC"
}

resource "aws_security_group_rule" "egress" {
    type = "egress"
    protocol = "-1"
    from_port = 0
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    security_group_id = aws_security_group.dns.id
    description = "Egress to anywhere"
}


resource "aws_security_group" "r53_resolver" {
    name = "Route 53 Outbound Resolver"
    description = "Allow Route 53 Resolver outbound access"
    vpc_id = aws_vpc.vpc.id
    revoke_rules_on_delete = true

    tags = {
        Name = "${var.tag_prefix}Route 53 Outbound Resolver${var.tag_suffix}"
    }
}

resource "aws_security_group_rule" "r53_ingress_udp" {
    type = "ingress"
    protocol = "udp"
    from_port = 0
    to_port = 0
    cidr_blocks = [aws_vpc.vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
    security_group_id = aws_security_group.r53_resolver.id
    description = "Ingress on all UDP ports intra-vpc"
}

resource "aws_security_group_rule" "r53_ingress_tcp" {
    type = "ingress"
    protocol = "tcp"
    from_port = 0
    to_port = 0
    cidr_blocks = [aws_vpc.vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
    security_group_id = aws_security_group.r53_resolver.id
    description = "Ingress on all TCP ports intra-vpc"
}

resource "aws_security_group_rule" "r53_egress_udp" {
    type = "egress"
    protocol = "udp"
    from_port = 53
    to_port = 53
    cidr_blocks = [aws_vpc.vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
    security_group_id = aws_security_group.r53_resolver.id
    description = "Egress to DNS UDP intra-vpc"
}

resource "aws_security_group_rule" "r53_egress_tcp" {
    type = "egress"
    protocol = "tcp"
    from_port = 53
    to_port = 53
    cidr_blocks = [aws_vpc.vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.vpc.ipv6_cidr_block]
    security_group_id = aws_security_group.r53_resolver.id
    description = "Egress to DNS TCP intra-vpc"
}
