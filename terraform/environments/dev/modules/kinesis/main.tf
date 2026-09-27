resource "aws_kinesis_stream" "sensor_stream" {
  name             = "sensor-stream-${var.environment}"
  shard_count      = var.shard_count
  retention_period = var.retention_hours

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Name        = "kinesis-sensor-stream-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
