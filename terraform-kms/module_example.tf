module "encryption_key" {
  source = "./modules/kms"
  
  description          = "Encryption key for application data"
  alias_name           = "app-data-encryption-key"
  enable_key_rotation  = true
  
  # Optional custom policy
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam:204469479814:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
POLICY
  
  tags = {
    Environment = "Production"
    Project     = "MyApp"
  }
}
