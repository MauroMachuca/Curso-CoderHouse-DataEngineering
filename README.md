# Checkpoint 1: Infraestructura Base - DataOps

Este repositorio contiene la infraestructura como código (IaC) modularizada para el despliegue de una plataforma de datos segura en AWS, utilizando Terraform.

## Arquitectura Desplegada

* **Backend Remoto (Bootstrap):** Almacenamiento del `.tfstate` en Amazon S3 con cifrado habilitado y control de concurrencia (State Locking) mediante DynamoDB.
* **Módulo Network:** Despliegue de una VPC aislada, subredes privadas distribuidas en múltiples Zonas de Disponibilidad (AZs) y un VPC Gateway Endpoint para conexiones seguras y sin costo hacia S3.
* **Módulo Identity:** Implementación del principio de mínimo privilegio. Incluye un rol para procesamiento de datos (Lambda/Flink) con acceso acotado por prefijo en S3, y un rol de auditoría de solo lectura.

## Guía de Despliegue (Cómo inicializar el entorno)

**Paso 1: Configurar credenciales**
Asegúrate de tener configurado AWS CLI en tu entorno local con permisos de administrador:
`aws configure`

**Paso 2: Crear el Backend Remoto**
Posiciónate en la carpeta bootstrap para crear el S3 y DynamoDB que alojarán el estado:
`cd bootstrap`
`terraform init`
`terraform apply -auto-approve`

**Paso 3: Desplegar el Entorno de Desarrollo (Dev)**
Regresa a la raíz y dirígete al entorno de desarrollo:
`cd ../environments/dev`
`terraform init`
`terraform plan`
`terraform apply`