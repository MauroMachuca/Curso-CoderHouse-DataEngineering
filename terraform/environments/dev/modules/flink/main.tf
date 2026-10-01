# 0. Datos de la cuenta/región actuales (evita hardcodear el Account ID)
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# 1. Subir el código empaquetado (JAR nativo de Flink con conectores) a S3
resource "aws_s3_object" "flink_code" {
  bucket = var.s3_bucket_id
  key    = "scripts/lakehouse-streaming-job.jar"
  source = "${path.module}/../../../../../flink-app/target/lakehouse-streaming-job-1.0.0.jar"
  etag   = filemd5("${path.module}/../../../../../flink-app/target/lakehouse-streaming-job-1.0.0.jar")
}

# 2. Rol IAM para Flink
resource "aws_iam_role" "flink_role" {
  name = "flink-kinesis-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "kinesisanalytics.amazonaws.com" }
    }]
  })
}

# 3. Políticas de acceso (Kinesis, S3 y CloudWatch)
resource "aws_iam_role_policy" "flink_policy" {
  name = "flink-kinesis-policy"
  role = aws_iam_role.flink_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["kinesis:DescribeStream", "kinesis:GetShardIterator", "kinesis:GetRecords", "kinesis:ListShards"]
        Resource = var.stream_arn
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = ["${var.s3_bucket_arn}/*", var.s3_bucket_arn]
      },
      {
        Effect = "Allow"
        Action = ["logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/kinesis-analytics/flink-processor-${var.environment}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetPartition",
          "glue:CreatePartition",
          "glue:UpdatePartition"
        ]
        Resource = [
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${var.glue_database_name}",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*"
        ]
      }
    ]
  })
}

# 4. Aplicación Managed Service for Apache Flink
resource "aws_kinesisanalyticsv2_application" "flink_app" {
  name                   = "flink-processor-${var.environment}"
  runtime_environment    = "FLINK-1_15"
  service_execution_role = aws_iam_role.flink_role.arn

  application_configuration {
    application_code_configuration {
      code_content {
        s3_content_location {
          bucket_arn     = var.s3_bucket_arn
          file_key       = aws_s3_object.flink_code.key
          object_version = aws_s3_object.flink_code.version_id
        }
      }
      code_content_type = "ZIPFILE"
    }



    flink_application_configuration {
      checkpoint_configuration {
        configuration_type     = "CUSTOM"
        checkpointing_enabled  = true
        checkpoint_interval    = 60000
        min_pause_between_checkpoints = 5000
      }

      monitoring_configuration {
        configuration_type = "CUSTOM"
        log_level          = "INFO"
        metrics_level      = "TASK"
      }
    }
  }
}