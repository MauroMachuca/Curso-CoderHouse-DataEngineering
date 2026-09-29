output "workgroup_endpoint" {
  value       = aws_redshiftserverless_workgroup.lakehouse.endpoint
  description = "Endpoint de conexion del workgroup (usalo en Query Editor v2 / drivers SQL)."
}
output "namespace_name" {
  value = aws_redshiftserverless_namespace.lakehouse.namespace_name
}
output "workgroup_name" {
  value = aws_redshiftserverless_workgroup.lakehouse.workgroup_name
}
output "redshift_role_arn" {
  value = aws_iam_role.redshift_role.arn
}
