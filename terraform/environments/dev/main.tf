# 0. Datos de la cuenta actual (evita hardcodear o pedir el Account ID a mano)
data "aws_caller_identity" "current" {}

# 1. Invocación del Módulo de Red Base
module "network" {
    source = "./modules/network"
    environment = var.environment
    vpc_cidr = var.vpc_cidr
}
# 2. Bucket S3 para Data Lake (Capa RAW)
resource "aws_s3_bucket" "raw_bucket" {
    bucket = "datalake-raw-${var.environment}-${data.aws_caller_identity.current.account_id}"
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

# 4. Kinesis Data Stream (ingesta de eventos de sensores)
module "kinesis" {
  source      = "./modules/kinesis"
  environment = var.environment
}

module "flink" {
source        = "./modules/flink"  
  environment   = var.environment
  stream_arn    = module.kinesis.stream_arn
  glue_database_name = aws_glue_catalog_database.lakehouse_db.name
  
  # Usa las salidas de tu bucket S3 creado en la entrega 1
  s3_bucket_id  = aws_s3_bucket.raw_bucket.id
  s3_bucket_arn = aws_s3_bucket.raw_bucket.arn
}


# 5. Redshift Serverless (namespace + workgroup + rol IAM propio)
module "redshift" {
  source              = "./modules/redshift"
  environment         = var.environment
  admin_password      = var.redshift_admin_password
  vpc_id              = module.network.vpc_id
  subnet_ids          = module.network.private_subnet_ids
  kinesis_stream_arn  = module.kinesis.stream_arn
  glue_database_name  = aws_glue_catalog_database.lakehouse_db.name
  raw_bucket_arn      = aws_s3_bucket.raw_bucket.arn
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
