variable "aws_region" {
    type = string
    default = "us-east-1"
}
variable "environment" {
    type = string
    default = "dev"
}
variable "vpc_cidr" {
    type = string
    default = "10.0.0.0/16"
}
variable "account_id" {
    type = string
    description = "ID de cuenta de AWS para sufijo único"
    default = "123456789012"
}

variable "redshift_admin_password" {
  type        = string
  description = "Contraseña para el cluster de Redshift"
  sensitive   = true
}