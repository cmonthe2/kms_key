resource "aws_kms_key" "monthly_key" {
  description             = "Monthly usage encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = {
    Environment = "prod"
    Team        = "Security"
  }
}


resource "aws_kms_alias" "monthly_key_alias" {
  name          = "alias/monthly-key"
  target_key_id = aws_kms_key.monthly_key.key_id
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






resource "aws_kms_key_policy" "AWSBackupServiceKey" {
  key_id = aws_kms_key.AWSBackupServiceKey.key_id

  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-consolepolicy-3",
    Statement = [
      {
        Sid      = "Enable IAM User Permissions",
        Effect   = "Allow",
        Principal = {
          AWS = "arn:aws:iam::73783999:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid      = "Allow access for Key Administrators",
        Effect   = "Allow",
        Principal = {
          AWS = "arn:aws:iam::7378388:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_AdministratorAccess_b99ad3d2e12b5b7c"
        },
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion"
        ],
        Resource = "*"
      }
    ]
  })
}
