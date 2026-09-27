output "stream_arn" {
  value       = aws_kinesis_stream.sensor_stream.arn
  description = "ARN del Kinesis Data Stream, consumido por el modulo de Flink."
}
output "stream_name" {
  value       = aws_kinesis_stream.sensor_stream.name
  description = "Nombre del stream, usado por sensor_producer.py y prueba_en_vivo.py."
}
