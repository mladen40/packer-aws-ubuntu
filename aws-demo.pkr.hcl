packer {
  required_plugins {
    amazon = {
      version = ">= 1.5.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "ami_prefix" {
  type        = string
  default     = "aws-ubuntu-26"
  description = "Prefix for the AMI name."
}

variable "aws_region" {
  type        = string
  default     = "us-west-2"
  description = "AWS region to build the AMI in."
}

variable "instance_type" {
  type        = string
  default     = "t4g.micro"
  description = "EC2 instance type for the build (ARM64 for ubuntu-noble arm64)."
}

locals {
  timestamp  = regex_replace(timestamp(), "[- TZ:]", "")
  build_date = formatdate("MM-DD-YYYY", timestamp())
}

source "amazon-ebs" "ubuntu_aws" {
  ami_name        = "${var.ami_prefix}-${local.timestamp}"
  ami_description = "Ubuntu 26.04 (Resolute Raccoon) - ${var.ami_prefix}"
  instance_type   = var.instance_type
  region          = var.aws_region
  imds_support    = "v2.0"

  source_ami_filter {
    filters = {
      name                 = "ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-arm64-server-*"
      root-device-type     = "ebs"
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

  tags = {
    Name        = "${var.ami_prefix}-${local.build_date}"
    PackerBuild = "true"
    BaseAMI     = "ubuntu-resolute-26.04-arm64"
  }
}

build {
  name = "packer-ubuntu"
  sources = [
    "source.amazon-ebs.ubuntu_aws"
  ]

  provisioner "shell" {
    inline = [
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
      "sudo apt-get update -qq",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wget apt-transport-https gnupg2 software-properties-common auditd coreutils curl git jq util-linux nfs-common",
      "sudo apt-get upgrade -y -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'",
      "sudo rm -f /var/log/ubuntu-advantage.log",
      "echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf",
      "echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -w net.core.default_qdisc=fq || true",
      "sudo sysctl -w net.ipv4.tcp_congestion_control=bbr || true",
      "sudo cloud-init clean --machine-id"
    ]
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive"
    ]
  }

  post-processor "manifest" {
    output     = "packer-manifest.json"
    strip_path = true
  }
}
