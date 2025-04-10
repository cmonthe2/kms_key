resource "aws_kms_key" "key" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  policy                  = var.policy
  tags                    = var.tags
  key_usage               = var.key_usage
  customer_master_key_spec = var.customer_master_key_spec
  multi_region            = var.multi_region
}

resource "aws_kms_alias" "alias" {
  count         = var.alias_name != "" ? 1 : 0
  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.key.id
}
