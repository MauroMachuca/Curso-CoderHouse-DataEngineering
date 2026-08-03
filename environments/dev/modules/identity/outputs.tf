output "role_arn" {
    value = aws_iam_role.data_processing_role.arn
    description = "ARN del Rol IAM configurado"
}
output "role_name" {
    value = aws_iam_role.data_processing_role.name
    description = "Nombre del Rol IAM"
}

output "audit_role_arn" {
  value       = aws_iam_role.audit_role.arn
  description = "ARN del Rol IAM de auditoría (Solo lectura)"
}