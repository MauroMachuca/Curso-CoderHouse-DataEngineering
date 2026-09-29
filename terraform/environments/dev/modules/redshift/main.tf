data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "redshift_role" {
  name = "redshift-lakehouse-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "redshift.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "redshift_policy" {
  name = "redshift-lakehouse-policy"
  role = aws_iam_role.redshift_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadKinesisStream"
        Effect   = "Allow"
        Action   = ["kinesis:DescribeStreamSummary", "kinesis:GetShardIterator", "kinesis:GetRecords", "kinesis:DescribeStream"]
        Resource = var.kinesis_stream_arn
      },
      {
        Sid      = "ListKinesisStreams"
        Effect   = "Allow"
        Action   = ["kinesis:ListStreams", "kinesis:ListShards"]
        Resource = "*"
      },
      {
        Sid    = "ReadGlueCatalog"
        Effect = "Allow"
        Action = ["glue:GetDatabase", "glue:GetTable", "glue:GetTables", "glue:GetPartition", "glue:GetPartitions"]
        Resource = [
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:database/${var.glue_database_name}",
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.glue_database_name}/*"
        ]
      },
      {
        Sid      = "ReadLakehouseS3"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [var.raw_bucket_arn, "${var.raw_bucket_arn}/*"]
      }
    ]
  })
}

resource "aws_security_group" "redshift_sg" {
  name        = "redshift-sg-${var.environment}"
  description = "Permite conexiones al puerto 5439 de Redshift Serverless"
  vpc_id      = var.vpc_id

  ingress {
    description = "Redshift (dev - acotar en produccion)"
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "redshift-sg-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_redshiftserverless_namespace" "lakehouse" {
  namespace_name       = "lakehouse-${var.environment}"
  admin_username        = var.admin_username
  admin_user_password   = var.admin_password
  db_name               = "dev"
  iam_roles             = [aws_iam_role.redshift_role.arn]
  default_iam_role_arn  = aws_iam_role.redshift_role.arn

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_redshiftserverless_workgroup" "lakehouse" {
  namespace_name      = aws_redshiftserverless_namespace.lakehouse.namespace_name
  workgroup_name      = "lakehouse-wg-${var.environment}"
  base_capacity       = var.base_capacity
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.redshift_sg.id]
  publicly_accessible = true

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
