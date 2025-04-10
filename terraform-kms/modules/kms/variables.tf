variable "description" {
  description = "Description for the KMS key"
  type        = string
  default     = "KMS key managed by Terraform"
}

variable "deletion_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction of the resource"
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Specifies whether key rotation is enabled"
  type        = bool
  default     = true
}

variable "alias_name" {
  description = "The name of the key alias without the alias/ prefix"
  type        = string
  default     = ""
}

variable "policy" {
  description = "A valid KMS policy JSON document"
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to add to the KMS key"
  type        = map(string)
  default     = {}
}

variable "key_usage" {
  description = "Specifies the intended use of the key"
  type        = string
  default     = "ENCRYPT_DECRYPT"
}

variable "customer_master_key_spec" {
  description = "Specifies whether the key contains a symmetric key or an asymmetric key pair"
  type        = string
  default     = "SYMMETRIC_DEFAULT"
}

variable "multi_region" {
  description = "Indicates whether the KMS key is a multi-Region key"
  type        = bool
  default     = false
}
