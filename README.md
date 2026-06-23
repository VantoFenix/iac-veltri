# Veltri Minimarket - Infraestructura como Código (IaC)

Este repositorio contiene todo el código fuente para el despliegue automatizado de la infraestructura en AWS para el proyecto Veltri Minimarket, utilizando el enfoque de **Infraestructura Inmutable**.

## 🏗️ Arquitectura y Tecnologías

El aprovisionamiento y configuración se divide en tres herramientas principales, logrando una separación limpia de responsabilidades:

1. **[Ansible](https://www.ansible.com/): Configuración Base (El Terreno)**
   Se encarga de instalar las herramientas necesarias a nivel de sistema operativo (Docker, AWS CLI, Agente de CloudWatch) y de aplicar estándares de seguridad sin ejecutar la aplicación directamente.

2. **[Packer](https://www.packer.io/): Imágenes Inmutables (El Horneado)**
   Automatiza la creación de una "Golden AMI" en AWS. Packer levanta una máquina temporal, llama a Ansible para configurarla, y guarda la imagen final. Esto acelera dramáticamente el arranque de las instancias en el Auto Scaling Group.

3. **[Terraform](https://www.terraform.io/): Orquestación (El Despliegue)**
   Orquesta todos los recursos de AWS agrupados en módulos. Consumiendo la Golden AMI generada por Packer, levanta la infraestructura de red, seguridad, bases de datos y cómputo.

---

## 📂 Estructura del Repositorio

```text
├── ansible/                  # Roles y playbooks para configurar la AMI
│   ├── golden-ami.yml        # Playbook principal
│   └── roles/                # Roles para Docker, CloudWatch y OS Base
├── packer/                   # Plantillas para creación de imágenes
│   └── app-ami.pkr.hcl       # Plantilla de la Golden AMI
├── infra/                    # Código principal de Terraform
│   ├── main.tf               # Orquestador raíz
│   └── modules/              # Módulos separados por dominio de negocio
│       ├── network/          # VPC, Subredes, NAT, IGW
│       ├── compute/          # EC2, Auto Scaling, ALB, ECR, IAM
│       ├── data/             # RDS (Aurora), Redis, Secrets Manager
│       ├── edge/             # CloudFront, WAF, API Gateway
│       └── dns/              # Route53 (Dominios y registros)
├── .github/workflows/        # Pipelines CI/CD de GitHub Actions
└── Dockerfile                # Receta para construir la app principal
```

---

## 📋 Prerrequisitos

Para ejecutar este proyecto de forma local, necesitas tener instalados:

*   [AWS CLI](https://aws.amazon.com/cli/) (Configurado con tus credenciales: `aws configure`)
*   [Terraform](https://developer.hashicorp.com/terraform/install) (v1.5.0+)
*   [Packer](https://developer.hashicorp.com/packer/install) (v1.8.0+)
*   Git

> **Nota sobre Ansible:** No es necesario tener Ansible instalado localmente. Packer ha sido configurado para usar el provisioner `ansible-local`, el cual instala y ejecuta Ansible directamente dentro de la máquina temporal en AWS.

---

## 🚀 Guía de Despliegue Manual

### Paso 0: Autenticación con AWS
Antes de ejecutar cualquier comando, asegúrate de que tu terminal tiene los permisos necesarios para hablar con tu cuenta de AWS. Si tienes credenciales temporales o de IAM, expórtalas en tu consola o configúralas ejecutando:
```bash
aws configure
```
*(También puedes validar que tienes acceso ejecutando `aws sts get-caller-identity`)*

### Paso 1: Generar la Golden AMI (Packer)
Este paso crea la imagen base con Docker preinstalado. Toma alrededor de 3-5 minutos.

```bash
cd packer
packer init .
packer build app-ami.pkr.hcl
```
Al finalizar, Packer mostrará el ID de la nueva AMI generada. No necesitas copiar este ID manualmente.

### Paso 2: Desplegar la Infraestructura (Terraform)
Terraform buscará de forma dinámica la última AMI generada por Packer en el paso anterior y la usará para el Launch Template del Auto Scaling Group.

```bash
cd infra
terraform init
terraform plan
terraform apply -auto-approve
```

---

## 🔄 Integración Continua (CI/CD)

El repositorio incluye automatización a través de **GitHub Actions**:
*   `terraform-deploy.yml`: Validación y despliegue automático de la infraestructura.
*   `docker-build-push.yml`: Construcción de la imagen Docker de la aplicación y publicación al repositorio de ECR.
*   `sonarqube-analysis.yml`: Análisis estático de código para calidad y seguridad.
