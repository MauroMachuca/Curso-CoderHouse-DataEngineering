# 1) indicamos a terraform que vamos a usar el proveedor de AWS
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 2) indicamos cual es la región donde vamos a trabajar
provider "aws" {
  region = "us-east-1"
}

# 3) definimos el bucket de S3 que vamos a crear (Capa Raw, es decir donde residen los datos crudos)
resource "aws_s3_bucket" "data_lake_raw" {

  # Nombre unico a nuivel global en aws  
  bucket = "curso-data-engineering-datalake-raw-prueba"
  # le damos el permiso a terraform de eliminar el bucket aunque tenga objetos dentro
  force_destroy = true
  
  tags = {
    Environment = "Dev"
    Project     = "DataOps-Course-DataLake"
  }
}