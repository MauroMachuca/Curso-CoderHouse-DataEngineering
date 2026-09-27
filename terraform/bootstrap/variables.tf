# ------------------------------------------------------------------------------
# VARIABLES DE CONFIGURACIÓN DEL BOOTSTRAP
# Definimos valores por defecto para evitar escribirlos manualmente cada vez.
# ------------------------------------------------------------------------------
variable "aws_region" {
type = string
description = "Región de AWS donde se alojarán el Bucket S3 y DynamoDB del backend"
default = "us-east-1"
}
variable "environment" {
type = string
description = "Ambiente asociado a la infraestructura del backend"
default = "dev"
}