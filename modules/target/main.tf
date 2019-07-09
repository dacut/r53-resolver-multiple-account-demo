variable "keypair" { }
variable "lookup_instance_type" { default = "t3a.nano" }
variable "resolver_rule_id" { }
variable "vpc_cidr_block" { }
variable "zone_id" { }
variable "tag_prefix" { default = "" }
variable "tag_suffix" { default = "" }

provider "aws" { }
data "aws_availability_zones" "available" {
    # use1-az3 is capacity constrained
    # usw2-az4 lacks many networking features
    blacklisted_zone_ids = ["use1-az3", "usw2-az4"]
}

data "aws_ami" "amzn2" {
    most_recent = true
    filter {
        name = "architecture"
        values = ["x86_64"]
    }

    filter {
        name = "ena-support"
        values = ["true"]
    }

    filter {
        name = "name"
        values = ["amzn2-ami-hvm-2.0*"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }

    owners = ["045324592363", "137112412989"]
}