provider "aws" {
  region = "us-east-1"
}

resource "aws_kms_key" "key_f7fd450e_22b4_4c71_babc_debdcf8b4803" {
  description             = "key for dev "
  deletion_window_in_days = 30
  key_usage               = "ENCRYPT_DECRYPT"
  multi_region = false
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "key-consolepolicy-3",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::204469479814:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow access for Key Administrators",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::204469479814:user/terraform-learning"
      },
      "Action": [
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
        "kms:CancelKeyDeletion",
        "kms:RotateKeyOnDemand"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow use of the key",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::204469479814:user/terraform-learning"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow attachment of persistent resources",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::204469479814:user/terraform-learning"
      },
      "Action": [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ],
      "Resource": "*",
      "Condition": {
        "Bool": {
          "kms:GrantIsForAWSResource": "true"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_kms_alias" "alias_monthe" {
  name          = "alias/monthe"
  target_key_id = aws_kms_key.key_f7fd450e_22b4_4c71_babc_debdcf8b4803.key_id
}









data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid     = "AllowRootAccountFullAccess"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::123456789012:root"]
    }
    resources = ["*"]
  }

  statement {
    sid     = "AllowIAMRolesToUseKey"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals {
      type        = "AWS"
      identifiers = [
        "arn:aws:iam::123456789012:role/YourAppRole",
        "arn:aws:iam::123456789012:user/YourDevUser"
      ]
    }
    resources = ["*"]
  }

  statement {
    sid     = "AllowKeyAdminFullAccess"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::123456789012:role/KMSAdmin"]
    }
    resources = ["*"]
  }

  statement {
    sid     = "AllowAWSServiceIntegration"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals {
      type        = "Service"
      identifiers = [
        "glue.amazonaws.com",
        "sns.amazonaws.com",
        "s3.amazonaws.com",
        "logs.amazonaws.com",
        "lambda.amazonaws.com"
      ]
    }
    resources = ["*"]
  }
}
