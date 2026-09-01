# 1. Subir el código fuente a S3
resource "aws_s3_object" "flink_code" {
  bucket = var.s3_bucket_id
  key    = "scripts/flink_processor.zip"
  source = "../../../../src/flink_processor.py"                  
  etag   = filemd5("../../../../src/flink_processor.py")         
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
        Resource = "*"
      }
    ]
  })
}

# 4. Aplicación Managed Service for Apache Flink
resource "aws_kinesisanalyticsv2_application" "flink_app" {
  name                   = "flink-processor-${var.environment}"
  runtime_environment    = "FLINK-1_15" # Compatible con PyFlink estándar
  service_execution_role = aws_iam_role.flink_role.arn

  application_configuration {
    application_code_configuration {
      code_content {
        s3_content_location {
          bucket_arn = var.s3_bucket_arn
          file_key   = aws_s3_object.flink_code.key
        }
      }
      code_content_type = "ZIPFILE"
    }

    flink_application_configuration {
      # Tolerancia a fallos: Checkpoints activados guardados en S3
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