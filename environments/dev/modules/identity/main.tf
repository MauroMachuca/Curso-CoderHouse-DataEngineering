# ------------------------------------------------------------------------------
# 1. ROL DE SERVICIO (IAM Role)
# Define qué servicios pueden asumir este rol (Lambda / Flink).
# ------------------------------------------------------------------------------
resource "aws_iam_role" "data_processing_role" {
    name = "role-data-processing-${var.environment}"
    assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
    Action = "sts:AssumeRole"
    Effect = "Allow"
    Principal = {
    Service = ["lambda.amazonaws.com", "kinesisanalytics.amazonaws.com"]
    }
    }
    ]
    })
    tags = {
    Environment = var.environment
    ManagedBy = "Terraform"
    }
}
# ------------------------------------------------------------------------------
# 2. POLÍTICA DE PERMISOS ACOTADA
# Permite únicamente listar el bucket y operar en el prefijo especificado.
# ------------------------------------------------------------------------------
resource "aws_iam_policy" "strict_s3_policy" {
    name = "policy-s3-restricted-${var.environment}"
    description = "Permisos S3 acotados por prefijo sin comodines globales"
    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
    Sid = "ListBucketScope"
    Effect = "Allow"
    Action = ["s3:ListBucket"]
    Resource = [var.bucket_arn]
    },
    {
    Sid = "ObjectOperationsScope"
    Effect = "Allow"
    Action = ["s3:GetObject", "s3:PutObject"]
    Resource = ["${var.bucket_arn}/${var.prefix}"]
    }
    ]
    })
}
# ------------------------------------------------------------------------------
# 3. ASOCIACIÓN DE POLÍTICA AL ROL
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "attach_data_policy" {
    role = aws_iam_role.data_processing_role.name
    policy_arn = aws_iam_policy.strict_s3_policy.arn
}

# 4. ROL DE AUDITORÍA (Plano de control - Solo Lectura)
resource "aws_iam_role" "audit_role" {
  name = "role-audit-readonly-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "audit_attach" {
  role       = aws_iam_role.audit_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}