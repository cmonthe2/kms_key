#!/bin/bash

set -e

# Set your AWS CLI profile
export AWS_PROFILE=default # <-- replace with your profile name

mkdir -p kms_tf_output
cd kms_tf_output || exit 1

> aws_kms_key.tf
> aws_kms_key_policy.tf
> aws_kms_alias.tf
> kms_import.tf

KEYS=$(aws kms list-keys --query "Keys[*].KeyId" --output text)

for KEY_ID in $KEYS; do
  MANAGER=$(aws kms describe-key --key-id "$KEY_ID" --query "KeyMetadata.KeyManager" --output text)

  if [[ "$MANAGER" == "CUSTOMER" ]]; then
    echo "Processing key: $KEY_ID"

    METADATA=$(aws kms describe-key --key-id "$KEY_ID" --query "KeyMetadata")
    ALIAS_NAME=$(aws kms list-aliases --query "Aliases[?TargetKeyId=='$KEY_ID'].AliasName" --output text | head -n1)
    TAGS_JSON=$(aws kms list-resource-tags --key-id "$KEY_ID" --query "Tags")
    POLICY_RAW=$(aws kms get-key-policy --key-id "$KEY_ID" --policy-name default --query "Policy" --output text)

    if [[ -z "$ALIAS_NAME" ]]; then
      RESOURCE_NAME="key_${KEY_ID:0:8}"
    else
      RESOURCE_NAME=$(echo "$ALIAS_NAME" | sed 's/alias\///g' | sed 's/[^a-zA-Z0-9_]/_/g')
    fi

    DESCRIPTION=$(echo "$METADATA" | jq -r '.Description')
    KEY_USAGE=$(echo "$METADATA" | jq -r '.KeyUsage')
    KEY_SPEC=$(echo "$METADATA" | jq -r '.CustomerMasterKeySpec')

    # Format tags to HCL
    TAGS_HCL=$(echo "$TAGS_JSON" | jq -r 'map("    \(.TagKey) = \"\(.TagValue)\"") | .[]')
    TAGS_BLOCK="tags = {\n$TAGS_HCL\n  }"

    # 1. aws_kms_key.tf
    cat >> aws_kms_key.tf <<EOF
resource "aws_kms_key" "$RESOURCE_NAME" {
  description             = "$DESCRIPTION"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  key_usage               = "$KEY_USAGE"
  customer_master_key_spec = "$KEY_SPEC"
  $TAGS_BLOCK
}

EOF

    # 2. aws_kms_key_policy.tf
    cat >> aws_kms_key_policy.tf <<EOF
resource "aws_kms_key_policy" "${RESOURCE_NAME}_policy" {
  key_id = aws_kms_key.$RESOURCE_NAME.id
  policy = <<POLICY
$POLICY_RAW
POLICY
}

EOF

    # 3. aws_kms_alias.tf
    if [[ -n "$ALIAS_NAME" ]]; then
      cat >> aws_kms_alias.tf <<EOF
resource "aws_kms_alias" "${RESOURCE_NAME}_alias" {
  name          = "$ALIAS_NAME"
  target_key_id = aws_kms_key.$RESOURCE_NAME.key_id
}

EOF
      # Add import block for alias
      cat >> kms_import.tf <<EOF
import {
  to = aws_kms_alias.${RESOURCE_NAME}_alias
  id = "$ALIAS_NAME"
}

EOF
    fi

    # 4. Import blocks for key and key policy
    cat >> kms_import.tf <<EOF
import {
  to = aws_kms_key.$RESOURCE_NAME
  id = "$KEY_ID"
}

import {
  to = aws_kms_key_policy.${RESOURCE_NAME}_policy
  id = "$KEY_ID"
}

EOF

  fi
done

echo "✅ Terraform files and import blocks generated in $(pwd):"
ls -1
