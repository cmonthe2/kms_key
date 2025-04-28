
data "aws_iam_policy_document" "eig_uw2_cloudwatch_logs_kms_data_polciy" {
  version = "2012-10-17"
  policy_id = "key-consolepolicy-3"

  statement {
    sid = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = ["arn:aws:iam::777777:root"]
    }
    actions = ["kms:*"]
    resources = ["arn:aws:kms:us-west-2:779999:key/0b181318-6567-4520-bb8d-9d78a9779f7105c2"]
  }

  statement {
    sid = "Allow access for Key Administrators"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = ["arn:aws:iam::6777777:role/aws-reserved/sso.amazonaws.com/us-west-2/AWSReservedSSO_AdministratorAccess_b99ad3d2e9912b5b7c"]
    }
    actions = [
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
    ]
    resources = ["arn:aws:kms:us-west-2:997766666666:key/0b181318-6567-4520-uu0u-9d78af7105uu0u02"]
  }

  statement {
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = ["logs.us-west-2.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["arn:aws:kms:us-west-2:667778888:key/0b181318-6567-4520-bb8d-9d78af7105c2"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:us-west-2:68899999:*"]
    }
  }
}
