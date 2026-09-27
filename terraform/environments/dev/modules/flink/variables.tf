variable "environment" { type = string }
variable "stream_arn" { type = string }
variable "s3_bucket_id" { type = string }
variable "s3_bucket_arn" { type = string }
variable "glue_database_name" {
  type        = string
  description = "Nombre de la base de Glue, para acotar los permisos IAM en vez de usar Resource = \"*\""
}