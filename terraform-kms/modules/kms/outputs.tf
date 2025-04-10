output "key_id" {
  description = "The globally unique identifier for the key"
  value       = aws_kms_key.key.id
}

output "key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = aws_kms_key.key.arn
}

output "alias_arn" {
  description = "The Amazon Resource Name (ARN) of the key alias"
  value       = length(aws_kms_alias.alias) > 0 ? aws_kms_alias.alias[0].arn : null
}
