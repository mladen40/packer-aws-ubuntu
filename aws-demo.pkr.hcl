packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "ami_prefix" {
  type    = string
  default = "packer-aws-ubuntu"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu_aws" {
  ami_name      = "${var.ami_prefix}-${local.timestamp}"
  instance_type = "t2.micro"
  region        = "us-west-2"
  imds_support  = "v2.0"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-kinetic-22.10-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
}

build {
  name = "packer-ubuntu"
  sources = [
    "source.amazon-ebs.ubuntu_aws"
  ]

  provisioner "shell" {

    inline = [
      "echo Install - START ___",
      "sleep 10",
      "sudo apt-get update && sudo apt upgrade -y",
      "sudo apt-get install -y wget apt-transport-https gnupg2 software-properties-common auditd coreutils curl git jq util-linux nfs-common",
      "echo Install - SUCCESS___",
    ]
  }
}
