variable "environment" { type = string }

variable "admin_username" {
  type        = string
  default     = "admin_lakehouse"
  description = "Usuario admin del namespace de Redshift Serverless."
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Password del usuario admin. Se pasa via terraform.tfvars (nunca se commitea, esta en .gitignore)."
}

variable "base_capacity" {
  type        = number
  default     = 8
  description = "RPUs base del workgroup (minimo 8, multiplo de 8). No subir sin necesidad para evitar costos innecesarios."
}

variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "kinesis_stream_arn" { type = string }
variable "glue_database_name" { type = string }
variable "raw_bucket_arn" { type = string }
