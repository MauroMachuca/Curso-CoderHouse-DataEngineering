# 1. Invocación del Módulo de Red Base
module "network" {
    source = "./modules/network"
    environment = var.environment
    vpc_cidr = var.vpc_cidr
}
# 2. Bucket S3 para Data Lake (Capa RAW)
resource "aws_s3_bucket" "raw_bucket" {
    bucket = "datalake-raw-${var.environment}-${var.account_id}"
    force_destroy = true
    tags = {
    Name = "Data Lake Raw Bucket"
    Environment = var.environment
    ManagedBy = "Terraform"
    }
}
# 3. Invocación del Módulo IAM Acotado
module "identity" {
    source = "./modules/identity"
    environment = var.environment
    bucket_arn = aws_s3_bucket.raw_bucket.arn
    prefix = "raw-data/*"
}

module "flink" {
source        = "./modules/flink"  
  environment   = var.environment
  stream_arn    = module.kinesis.stream_arn
  
  # Usa las salidas de tu bucket S3 creado en la entrega 1
  s3_bucket_id  = aws_s3_bucket.raw_bucket.id
  s3_bucket_arn = aws_s3_bucket.raw_bucket.arn
}


#Pre entrega 5
# 1. Habilitar versionado en el Bucket S3 existente (Requisito para Iceberg)
resource "aws_s3_bucket_versioning" "raw_bucket_versioning" {
  bucket = aws_s3_bucket.raw_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 2. Base de datos del Catálogo de AWS Glue (Lakehouse)
resource "aws_glue_catalog_database" "lakehouse_db" {
  name        = "lakehouse_db"
  description = "Catálogo central para tablas Iceberg del Lakehouse"
}