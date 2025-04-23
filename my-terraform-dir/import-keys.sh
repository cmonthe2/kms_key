resource "aws_kms_key" "monthly_key" {
  description             = "Monthly usage encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = {
    Environment = "prod"
    Team        = "Security"
  }
}


aws kms describe-key --key-id <your-key-id> \
  --query 'KeyMetadata.[KeySpec, KeyUsage, KeyManager, KeyState, Origin, KeyType]' \
  --output table


resource "aws_kms_key" "monthly_key" {
  description             = "Encrypt monthly reports"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  key_usage                = "ENCRYPT_DECRYPT"
  tags = {
    Owner = "DataTeam"
    Env   = "Prod"
  }
}








resource "aws_kms_key_policy" "monthly_key_policy" {
  key_id = aws_kms_key.monthly_key.key_id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::123456789012:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::123456789012:role/KMSAccessRole"
        },
        "Action": [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ],
        "Resource": "*"
      }
    ]
  })
}
