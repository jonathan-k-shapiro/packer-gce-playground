packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.1"
      source = "github.com/hashicorp/googlecompute"
    }
  }
}

variable "project_id" {
  type = string
}

variable "zone" {
  type = string
}

source "googlecompute" "default" {
  project_id        = var.project_id
  zone              = var.zone
  source_image_family = "ubuntu-2204-lts"
  machine_type      = "e2-micro"
  image_name        = "my-custom-image-1234"
  image_family      = "my-custom-image-family"
  ssh_username      = "ubuntu"
  metadata = {
    enable-oslogin = "TRUE"
  }
}

build {
  sources = ["source.googlecompute.default"]

  # Wait for cloud-init to complete so that apt-get doesn't fail transiently
  provisioner "shell"{
    inline = [
      "cloud-init status --wait"
    ]
  } 

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y golang-go git"
    ]
  }

  # Clone Repositories and Compile Binaries
  provisioner "shell" {
    inline = [
      "mkdir -p opt/myapp",
      "cd opt/myapp",
      "git clone https://github.com/go-kit/examples.git",
      "cd examples",
      "sudo go build -o /usr/local/bin/profilesvc ./profilesvc/cmd/profilesvc/"
    ]
  }

  # Copy Systemd Unit Files
    provisioner "file" {
    source      = "profilesvc.service"
    destination = "opt/myapp/profilesvc.service"
  }

  # Enable Systemd Services
  provisioner "shell" {
    inline = [
      "sudo cp opt/myapp/profilesvc.service /etc/systemd/system/profilesvc.service",
      "sudo systemctl enable profilesvc"
    ]
  }

  # Cleanup source code
  provisioner "shell" {
    inline = [
      "rm -rf opt/myapp"
    ]
  }
}
