
#  MANIFIESTO DE INFRAESTRUCTURA EN VIVO - VELTRI MINIMARKET

Este archivo registra de forma transparente los identificadores físicos y puntos de conexión de los recursos desplegados en la nube de AWS en el entorno de desarrollo (`dev`).

---

##  CAPA DE COMUNICACIONES CORE & PERÍMETRO (Bruno)

* **Región de AWS:** `us-east-1`
* **VPC CIDR Block:** `10.0.0.0/16`
* **Subredes Públicas (Capa Web / NAT):**
* `us-east-1a (public_1):` `10.0.1.0/24`
* `us-east-1b (public_2):` `10.0.2.0/24`


* **Subredes Privadas de Procesamiento (EC2 / Lambda):**
* `us-east-1a (private_3_compute):` `10.0.3.0/24`
* `us-east-1b (private_4_compute):` `10.0.4.0/24`


* **Subredes Privadas de Datos Aislados:**
* `us-east-1a (private_5_data):` `10.0.5.0/24`
* `us-east-1b (private_6_data):` `10.0.6.0/24`


* **Amazon API Gateway:** Rest API configurada como Regional.

---

##  CAPA DE PERSISTENCIA Y CACHÉ (Asignado a: Josué)

* **Amazon Aurora Cluster Endpoint (Writer):** [Pendiente de llenado por Josué]
* **Amazon Aurora Reader Endpoint:** [Pendiente de llenado por Josué]
* **Amazon ElastiCache Redis Endpoint:** [Pendiente de llenado por Josué]
* **AWS Secrets Manager ARN:** [Pendiente de llenado por Josué]
* **Security Group Data ID:** [Pendiente de llenado por Josué]

---

##  CAPA DE CÓMPUTO Y ESCALABILIDAD (Asignado a: Wilmer)

* **Application Load Balancer DNS Name:** [Pendiente de llenado por Wilmer]
* **AWS ECR Repository URI:** [Pendiente de llenado por Wilmer]
* **Auto Scaling Group Name:** [Pendiente de llenado por Wilmer]
* **Security Group Compute ID:** [Pendiente de llenado por Wilmer]

---

## CAPA PERIMETRAL, CDN Y MENSAJERÍA (Asignado a: Tiago)

* **Amazon CloudFront URL:** [Pendiente de llenado por Tiago]
* **Amazon SQS Queue URL / ARN:** [Pendiente de llenado por Tiago]
* **AWS Lambda Function ARN:** [Pendiente de llenado por Tiago]
* **AWS WAF Web ACL ID:** [Pendiente de llenado por Tiago]

---

