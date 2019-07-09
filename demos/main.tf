variable "target_account_profile" { }
variable "resolver_account_profile" { }
variable "keypair" { }

variable "target_vpc_cidr_block" { default = "10.199.0.0/16" }
variable "resolver_vpc_cidr_block" { default = "10.200.0.0/16" }
variable "private_zone_name" { default = "example.com" }
variable "region" { default = "us-west-2" }

variable "tag_prefix" { default = "R53 Resolver Demo - " }
variable "tag_suffix" { default = "" }

provider "aws" {
    alias = "target"
    profile = var.target_account_profile
    region = var.region
    version = "~> 2.18"
}

provider "aws" {
    alias = "resolver"
    profile = var.resolver_account_profile
    region = var.region
    version = "~> 2.18"
}

provider "null" {
    version = "~> 2.1"
}

data "aws_caller_identity" "target" {
    provider = aws.target
}

module "resolver" {
    source = "../modules/resolver"
    providers = {
        aws = aws.resolver
    }

    keypair = var.keypair
    private_zone_name = var.private_zone_name
    target_account_id = data.aws_caller_identity.target.account_id
    vpc_cidr_block = var.resolver_vpc_cidr_block

    tag_prefix = var.tag_prefix
    tag_suffix = var.tag_suffix
}

module "target" {
    source = "../modules/target"
    providers = {
        aws = aws.target
    }

    keypair = var.keypair
    resolver_rule_id = module.resolver.resolver_rule_id
    vpc_cidr_block = var.target_vpc_cidr_block
    zone_id = module.resolver.zone_id

    tag_prefix = var.tag_prefix
    tag_suffix = var.tag_suffix
}

resource "null_resource" "associate_vpc" {
    provisioner "local-exec" {
        command = "${path.module}/../add_cross_account_phz --resolver-profile ${var.resolver_account_profile} --target-profile ${var.target_account_profile} --zone-id ${module.resolver.zone_id} --target-vpc-id ${module.target.vpc_id} --target-vpc-region ${var.region}"
    }
}

resource "null_resource" "accept_invitation" {
    provisioner "local-exec" {
        command = "aws --profile ${var.target_account_profile} ram accept-resource-share-invitation --resource-share-invitation-arn $(aws --output text --profile ${var.target_account_profile} ram get-resource-share-invitations --resource-share-arns ${module.resolver.resource_share_arn} --query 'resourceShareInvitations[0].resourceShareInvitationArn')"
    }
}

resource "null_resource" "wait_for_resolver_rule" {
    provisioner "local-exec" {
        command = "while ! aws --profile ${var.target_account_profile} route53resolver get-resolver-rule --resolver-rule-id ${module.resolver.resolver_rule_id}; do sleep 5; done"
    }
}

resource "aws_route53_resolver_rule_association" "fwd" {
    provider = aws.target
    depends_on = [null_resource.accept_invitation, null_resource.wait_for_resolver_rule]
    vpc_id = module.target.vpc_id
    resolver_rule_id = module.resolver.resolver_rule_id
}

output "resolver_vpc_id" {
    value = module.resolver.vpc_id
}

output "target_vpc_id" {
    value = module.target.vpc_id
}

output "zone_id" {
    value = module.resolver.zone_id
}

output "dns_instance_ipv4" {
    value = module.resolver.dns_ipv4_address
}

output "lookup_instance_ipv4" {
    value = module.target.lookup_ipv4_address
}

output "resolver_rule_id" {
    value = module.resolver.resolver_rule_id
}