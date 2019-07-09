resource "aws_route53_zone" "phz" {
    name = var.private_zone_name
    comment = "${var.tag_prefix}Private Hosted Zone ${var.private_zone_name}${var.tag_suffix}"
    force_destroy = true
    tags = {
        Name = "${var.tag_prefix}Private Hosted Zone ${var.private_zone_name}${var.tag_suffix}"
    }

    vpc {
        vpc_id = aws_vpc.vpc.id
    }

    lifecycle {
        ignore_changes = [vpc]
    }
}

resource "aws_route53_record" "base" {
    zone_id = aws_route53_zone.phz.zone_id
    name = "${var.private_zone_name}"
    type = "TXT"
    ttl = "10"
    records = ["${var.tag_prefix}Route 53 Private Hosted Zone${var.tag_suffix}"]
}

resource "aws_route53_record" "test" {
    zone_id = aws_route53_zone.phz.zone_id
    name = "test.${var.private_zone_name}"
    type = "TXT"
    ttl = "10"
    records = ["${var.tag_prefix}Route 53 Private Hosted Zone${var.tag_suffix}"]
}

resource "aws_instance" "dns" {
    ami = data.aws_ami.amzn2.id
    instance_type = var.dns_instance_type
    key_name = var.keypair
    monitoring = false
    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.dns.id
        delete_on_termination = false
    }
    tags = {
        Name = "${var.tag_prefix}External DNS${var.tag_suffix}"
    }
    user_data = <<EOF
#!/bin/bash
tag_prefix="${var.tag_prefix}"
tag_suffix="${var.tag_suffix}"
${file("${path.module}/dns_instance_init.sh")}
EOF
    volume_tags = {
        Name = "${var.tag_prefix}External DNS${var.tag_suffix}"
    }
    root_block_device {
        volume_type = "gp2"
        volume_size = 8
        delete_on_termination = true
    }
}

resource "aws_route53_resolver_endpoint" "out" {
    direction = "OUTBOUND"
    security_group_ids = [aws_security_group.r53_resolver.id]
    ip_address {
        subnet_id = aws_subnet.subnet[0].id
    }

    ip_address {
        subnet_id = aws_subnet.subnet[1].id
    }

    tags = {
        Name = "${var.tag_prefix}Outbound${var.tag_suffix}"
    }
}

resource "aws_route53_resolver_rule" "fwd" {
    resolver_endpoint_id = aws_route53_resolver_endpoint.out.id
    domain_name = "onprem.example.com"
    rule_type = "FORWARD"
    target_ip {
        ip = aws_network_interface.dns.private_ip
    }

    tags = {
        Name = "${var.tag_prefix}Forward rule for onprem.example.com${var.tag_suffix}"
    }
}

resource "aws_route53_resolver_rule_association" "fwd" {
    vpc_id = aws_vpc.vpc.id
    resolver_rule_id = aws_route53_resolver_rule.fwd.id
}

resource "aws_ram_resource_share" "resolver_rules" {
    name = "route53-resolver-rules"
    allow_external_principals = true
    tags = {
        Name = "${var.tag_prefix}Resolver rules${var.tag_suffix}"
    }
}

resource "aws_ram_resource_association" "resolver_rules" {
    resource_share_arn = aws_ram_resource_share.resolver_rules.arn
    resource_arn = aws_route53_resolver_rule.fwd.arn
}

resource "aws_ram_principal_association" "resolver_rules" {
    principal = var.target_account_id
    resource_share_arn = aws_ram_resource_share.resolver_rules.arn
}

output "dns_ipv4_address" {
    value = aws_eip.dns.public_ip
}

output "resource_share_arn" {
    value = aws_ram_resource_share.resolver_rules.arn
}

output "resolver_rule_id" {
    value = aws_route53_resolver_rule.fwd.id
}