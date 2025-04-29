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




#!/bin/bash

set -e

# Set your AWS CLI profile here
export AWS_PROFILE=default  # <-- change this to your profile name

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
    echo "🔍 Processing KMS key: $KEY_ID"

    METADATA=$(aws kms describe-key --key-id "$KEY_ID" --query "KeyMetadata")
    ALIAS_NAME=$(aws kms list-aliases --query "Aliases[?TargetKeyId=='$KEY_ID'].AliasName" --output text | head -n1)
    TAGS_JSON=$(aws kms list-resource-tags --key-id "$KEY_ID" --query "Tags")

    if [[ -z "$ALIAS_NAME" ]]; then
      RESOURCE_NAME="key_${KEY_ID:0:8}"
    else
      RESOURCE_NAME=$(echo "$ALIAS_NAME" | sed 's/alias\///g' | sed 's/[^a-zA-Z0-9_]/_/g')
    fi

    DESCRIPTION=$(echo "$METADATA" | jq -r '.Description')
    KEY_USAGE=$(echo "$METADATA" | jq -r '.KeyUsage')
    KEY_SPEC=$(echo "$METADATA" | jq -r '.CustomerMasterKeySpec')

    TAGS_HCL=$(echo "$TAGS_JSON" | jq -r 'map("  \(.TagKey) = \"\(.TagValue)\"") | join("\n")')
    if [[ -n "$TAGS_HCL" ]]; then
      TAGS_BLOCK="tags = {\n$TAGS_HCL\n}"
    else
      TAGS_BLOCK=""
    fi

    # 1. Write aws_kms_key block
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

    # 2. Write data "aws_iam_policy_document" and aws_kms_key_policy
    cat >> aws_kms_key_policy.tf <<EOF
data "aws_iam_policy_document" "${RESOURCE_NAME}_doc" {
  statement {
    sid    = "AllowRootAccess"
    effect = "Allow"
    actions = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::123456789012:root"]
    }
  }
}

resource "aws_kms_key_policy" "${RESOURCE_NAME}_policy" {
  key_id = aws_kms_key.$RESOURCE_NAME.id
  policy = data.aws_iam_policy_document.${RESOURCE_NAME}_doc.json
}

EOF

    # 3. Write aws_kms_alias block if alias exists
    if [[ -n "$ALIAS_NAME" ]]; then
      cat >> aws_kms_alias.tf <<EOF
resource "aws_kms_alias" "${RESOURCE_NAME}_alias" {
  name          = "$ALIAS_NAME"
  target_key_id = aws_kms_key.$RESOURCE_NAME.key_id
}

EOF
      cat >> kms_import.tf <<EOF
import {
  to = aws_kms_alias.${RESOURCE_NAME}_alias
  id = "$ALIAS_NAME"
}

EOF
    fi

    # 4. Import blocks
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

echo "✅ HCL-style KMS files generated in $(pwd)"




































#!/bin/bash

set -e

# Set AWS CLI profile and region
export AWS_PROFILE=default
export AWS_REGION=us-west-2

mkdir -p kms_tf_output
cd kms_tf_output || exit 1

> aws_kms_key.tf
> aws_kms_key_policy.tf
> aws_kms_alias.tf
> aws_kms_policy_document.tf
> kms_import.tf

# Fetch AWS Account ID dynamically
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

KEYS=$(aws kms list-keys --query "Keys[*].KeyId" --output text)

for KEY_ID in $KEYS; do
  MANAGER=$(aws kms describe-key --key-id "$KEY_ID" --query "KeyMetadata.KeyManager" --output text)

  if [[ "$MANAGER" == "CUSTOMER" ]]; then
    echo "🔍 Processing KMS key: $KEY_ID"

    METADATA=$(aws kms describe-key --key-id "$KEY_ID" --query "KeyMetadata")
    ALIAS_NAME=$(aws kms list-aliases --query "Aliases[?TargetKeyId=='$KEY_ID'].AliasName" --output text | head -n1)
    TAGS_JSON=$(aws kms list-resource-tags --key-id "$KEY_ID" --query "Tags")

    if [[ -z "$ALIAS_NAME" ]]; then
      RESOURCE_NAME="key_${KEY_ID:0:8}"
    else
      RESOURCE_NAME=$(echo "$ALIAS_NAME" | sed 's/alias\///g' | sed 's/[^a-zA-Z0-9_]/_/g')
    fi

    DESCRIPTION=$(echo "$METADATA" | jq -r '.Description')
    KEY_USAGE=$(echo "$METADATA" | jq -r '.KeyUsage')
    KEY_SPEC=$(echo "$METADATA" | jq -r '.CustomerMasterKeySpec')

    TAGS_HCL=$(echo "$TAGS_JSON" | jq -r 'map("  \(.TagKey) = \"\(.TagValue)\"") | join("\n")')
    TAGS_BLOCK=""
    [[ -n "$TAGS_HCL" ]] && TAGS_BLOCK="tags = {\n$TAGS_HCL\n}"

    # 1. Write aws_kms_key block
    cat >> aws_kms_key.tf <<EOF
resource "aws_kms_key" "$RESOURCE_NAME" {
  description             = "$DESCRIPTION"
  bypass_policy_lockout_safety_check = false
  enable_key_rotation     = true
  key_usage               = "$KEY_USAGE"
  customer_master_key_spec = "$KEY_SPEC"
  $TAGS_BLOCK
}

EOF

    # 2. Write data "aws_iam_policy_document" block into aws_kms_policy_document.tf
    cat >> aws_kms_policy_document.tf <<EOF
data "aws_iam_policy_document" "${RESOURCE_NAME}_doc" {
  statement {
    sid    = "AllowRootAccess"
    effect = "Allow"
    actions = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${ACCOUNT_ID}:root"]
    }
  }
}

EOF

    # 3. Write aws_kms_key_policy resource
    cat >> aws_kms_key_policy.tf <<EOF
resource "aws_kms_key_policy" "${RESOURCE_NAME}_policy" {
  key_id = aws_kms_key.$RESOURCE_NAME.id
  policy = data.aws_iam_policy_document.${RESOURCE_NAME}_doc.json
}

EOF

    # 4. Write aws_kms_alias block if alias exists
    if [[ -n "$ALIAS_NAME" ]]; then
      cat >> aws_kms_alias.tf <<EOF
resource "aws_kms_alias" "${RESOURCE_NAME}_alias" {
  name          = "$ALIAS_NAME"
  target_key_id = aws_kms_key.$RESOURCE_NAME.key_id
}

EOF
      cat >> kms_import.tf <<EOF
import {
  to = aws_kms_alias.${RESOURCE_NAME}_alias
  id = "$ALIAS_NAME"
}

EOF
    fi

    # 5. Import blocks for key and policy
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

echo "✅ Done. Files generated in $(pwd)"




























#!/bin/bash

set -e

# Set AWS CLI profile and region
export AWS_PROFILE=default
mkdir -p kms_tf_output5
cd kms_tf_output5 || exit 1

> aws_kms_key.tf
> aws_kms_key_policy.tf
> aws_kms_alias.tf
> aws_kms_policy_document.tf
> kms_import.tf

# Fetch AWS Account ID dynamically
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

KEYS=$(aws kms list-keys --query "Keys[*].KeyId" --output text)

for KEY_ID in $KEYS; do
  MANAGER=$(aws kms describe-key --key-id "$KEY_ID" --query "KeyMetadata.KeyManager" --output text)

  if [[ "$MANAGER" == "CUSTOMER" ]]; then
    echo "🔍 Processing KMS key: $KEY_ID"

    METADATA=$(aws kms describe-key --key-id "$KEY_ID" --query "KeyMetadata")
    ALIAS_NAME=$(aws kms list-aliases --query "Aliases[?TargetKeyId=='$KEY_ID'].AliasName" --output text | head -n1)
    TAGS_JSON=$(aws kms list-resource-tags --key-id "$KEY_ID" --query "Tags")
    POLICY_FULL_JSON=$(aws kms get-key-policy --key-id "$KEY_ID" --policy-name default)
    POLICY_JSON=$(echo "$POLICY_FULL_JSON" | jq -r '.Policy')

    if [[ -z "$ALIAS_NAME" ]]; then
      RESOURCE_NAME="key_${KEY_ID:0:8}"
    else
      RESOURCE_NAME=$(echo "$ALIAS_NAME" | sed 's/alias\///g' | sed 's/[^a-zA-Z0-9_]/_/g')
    fi

    DESCRIPTION=$(echo "$METADATA" | jq -r '.Description')
    KEY_USAGE=$(echo "$METADATA" | jq -r '.KeyUsage')
    KEY_SPEC=$(echo "$METADATA" | jq -r '.CustomerMasterKeySpec')

    TAGS_HCL=$(echo "$TAGS_JSON" | jq -r 'map("  \(.TagKey) = \"\(.TagValue)\"") | join("\n")')
    TAGS_BLOCK=""
    [[ -n "$TAGS_HCL" ]] && TAGS_BLOCK="tags = {\n$TAGS_HCL\n}"

    # Write the KMS key resource
    cat >> aws_kms_key.tf <<EOF
resource "aws_kms_key" "$RESOURCE_NAME" {
  description             = "$DESCRIPTION"
  bypass_policy_lockout_safety_check = false
  enable_key_rotation     = true
  key_usage               = "$KEY_USAGE"
  customer_master_key_spec = "$KEY_SPEC"
  $TAGS_BLOCK
}

EOF

    # Generate HCL policy document from policy JSON
    VERSION=$(echo "$POLICY_JSON" | jq -r '.Version')
    POLICY_ID=$(echo "$POLICY_JSON" | jq -r '.Id')

    echo "data \"aws_iam_policy_document\" \"${RESOURCE_NAME}_doc\" {" >> aws_kms_policy_document.tf
    echo "  version = \"$VERSION\"" >> aws_kms_policy_document.tf
    echo "  policy_id = \"$POLICY_ID\"" >> aws_kms_policy_document.tf

    echo "$POLICY_JSON" | jq -c '.Statement[]' | while read -r stmt; do
      SID=$(echo "$stmt" | jq -r '.Sid // empty')
      EFFECT=$(echo "$stmt" | jq -r '.Effect')
      ACTIONS=$(echo "$stmt" | jq -r '.Action | if type=="string" then [.] else . end')
      RESOURCES=$(echo "$stmt" | jq -r '.Resource | if type=="string" then [.] else . end')
      PRINCIPALS=$(echo "$stmt" | jq -c '.Principal // empty')
      CONDITION=$(echo "$stmt" | jq -c '.Condition // empty')

      echo "  statement {" >> aws_kms_policy_document.tf
      [[ -n "$SID" ]] && echo "    sid    = \"$SID\"" >> aws_kms_policy_document.tf
      echo "    effect = \"$EFFECT\"" >> aws_kms_policy_document.tf

      echo "    actions = $(echo $ACTIONS | jq -c '.')" >> aws_kms_policy_document.tf
      echo "    resources = $(echo $RESOURCES | jq -c '.')" >> aws_kms_policy_document.tf

      if [[ "$PRINCIPALS" != "null" && -n "$PRINCIPALS" ]]; then
        for ptype in $(echo "$PRINCIPALS" | jq -r 'keys[]'); do
          IDS=$(echo "$PRINCIPALS" | jq -r --arg p "$ptype" '.[$p] | if type=="string" then [.] else . end')
          echo "    principals {" >> aws_kms_policy_document.tf
          echo "      type        = \"$ptype\"" >> aws_kms_policy_document.tf
          echo "      identifiers = $(echo $IDS | jq -c '.')" >> aws_kms_policy_document.tf
          echo "    }" >> aws_kms_policy_document.tf
        done
      fi

      if [[ "$CONDITION" != "null" && -n "$CONDITION" ]]; then
        for condition_operator in $(echo "$CONDITION" | jq -r 'keys[]'); do
          echo "    condition {" >> aws_kms_policy_document.tf
          echo "      test     = \"$condition_operator\"" >> aws_kms_policy_document.tf
          for condition_key in $(echo "$CONDITION" | jq -r --arg op "$condition_operator" '.[$op] | keys[]'); do
            echo "      variable = \"$condition_key\"" >> aws_kms_policy_document.tf
            VALUES=$(echo "$CONDITION" | jq -r --arg op "$condition_operator" --arg key "$condition_key" '.[$op][$key] | if type=="string" then [.] else . end')
            echo "      values   = $(echo $VALUES | jq -c '.')" >> aws_kms_policy_document.tf
          done
          echo "    }" >> aws_kms_policy_document.tf
        done
      fi

      echo "  }" >> aws_kms_policy_document.tf
    done

    echo "}" >> aws_kms_policy_document.tf

    # Write aws_kms_key_policy resource
    cat >> aws_kms_key_policy.tf <<EOF
resource "aws_kms_key_policy" "${RESOURCE_NAME}_policy" {
  key_id = aws_kms_key.$RESOURCE_NAME.id
  policy = data.aws_iam_policy_document.${RESOURCE_NAME}_doc.json
}

EOF

    # Write aws_kms_alias block if alias exists
    if [[ -n "$ALIAS_NAME" ]]; then
      cat >> aws_kms_alias.tf <<EOF
resource "aws_kms_alias" "${RESOURCE_NAME}_alias" {
  name          = "$ALIAS_NAME"
  target_key_id = aws_kms_key.$RESOURCE_NAME.key_id
}

EOF
      cat >> kms_import.tf <<EOF
import {
  to = aws_kms_alias.${RESOURCE_NAME}_alias
  id = "$ALIAS_NAME"
}

EOF
    fi

    # Import blocks
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

# Format terraform files automatically if terraform is installed
if command -v terraform &> /dev/null; then
  terraform fmt *.tf
fi

echo "✅ Done: Fully normalized HCL policies written in $(pwd)"


