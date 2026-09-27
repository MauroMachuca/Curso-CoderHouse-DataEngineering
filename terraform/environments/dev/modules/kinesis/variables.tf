variable "environment" {
  type        = string
  description = "Nombre del entorno (dev/prod), se usa como sufijo del stream."
}
variable "shard_count" {
  type        = number
  default     = 1
  description = "Cantidad de shards. 1 alcanza para el volumen de datos sinteticos del capstone."
}
variable "retention_hours" {
  type        = number
  default     = 24
  description = "Horas de retencion de los registros en el stream (24h = minimo sin costo extra)."
}
