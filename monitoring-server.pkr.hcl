# https://www.packer.io/docs/builders/googlecompute
packer {
  required_plugins {
    googlecompute = {
      source  = "github.com/hashicorp/googlecompute"
      version = "~> 1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "~> 1"
    }
  }
}

# Declare variables
variable "project_id" {}
variable "zone" {}
variable "arch" {}
variable "source_image_family" {}
variable "image_family" {}
variable "network" {
  description = "The network to attach this instance to"
  default     = "project-devops-share-rs-vpc" # Change this to your network if not using the default network
}
variable "subnetwork" {
  description = "The subnetwork to attach this instance to"
  default     = "project-devops-share-rs-applications-subnet-01" # Optional: Specify the subnetwork if needed
}

locals {
  # https://www.packer.io/docs/templates/hcl_templates/functions/datetime/formatdate
  datestamp = formatdate("YYYYMMDDHH", timestamp())
}

# https://www.packer.io/docs/builders/googlecompute#required
source "googlecompute" "monitoring" {
  project_id       = var.project_id
  credentials_file = "gcp-key.json"
  zone             = var.zone
  machine_type     = "e2-medium"
  ssh_username     = "root"
  use_os_login     = "false"

  # gcloud compute images list
  source_image_family = var.source_image_family

  image_family      = var.image_family
  image_name        = "monitoring-server-1-0-${var.arch}-base-${local.datestamp}"
  image_description = "Ubuntu Server Image For Dev"

  tags       = ["packer"]
  network    = var.network
  subnetwork = var.subnetwork

  disk_attachment {
    volume_type = "pd-ssd"
    volume_size = 20
    device_name = "disk-1"
  }
}

build {
  sources = [
    "source.googlecompute.monitoring"
  ]
  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y unzip",
      "curl -fsSL https://get.docker.com -o get-docker.sh",
      "sh get-docker.sh",
      "usermod -aG docker $USER"
    ]
  }

  # Copy Terraform configuration files
  provisioner "file" {
    source      = "./monitoring"
    destination = "/tmp/monitoring"
  }

  provisioner "shell" {
    inline = [
      "cd /tmp/monitoring",
      "docker compose up -d"
    ]
  }
}