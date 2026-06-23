packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID donde se levantará la instancia para compilar la AMI"
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID pública donde se levantará la instancia temporal"
  default     = ""
}

source "amazon-ebs" "app_ami" {
  ami_name      = "veltri-app-golden-ami-{{timestamp}}"
  instance_type = "t3.micro"
  region        = var.region
  
  # VPC y Subred son opcionales, si no se mandan Packer usa la VPC por defecto
  vpc_id        = var.vpc_id != "" ? var.vpc_id : null
  subnet_id     = var.subnet_id != "" ? var.subnet_id : null

  # Amazon Linux 2023 base
  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }

  ssh_username                = "ec2-user"
  associate_public_ip_address = true
  
  tags = {
    Name       = "Veltri-Golden-AMI"
    Proyecto   = "veltri"
    Gestionado = "Packer"
  }
}

build {
  sources = ["source.amazon-ebs.app_ami"]

  # Instalamos Ansible en la instancia temporal para que corra los playbooks localmente
  provisioner "shell" {
    inline = [
      "sudo dnf update -y",
      "sudo dnf install -y ansible"
    ]
  }

  # Usamos ansible-local para que no necesites tener Ansible instalado en tu Windows
  provisioner "ansible-local" {
    playbook_file = "../ansible/golden-ami.yml"
    role_paths    = [
      "../ansible/roles/os_base",
      "../ansible/roles/docker",
      "../ansible/roles/cloudwatch"
    ]
  }
}
