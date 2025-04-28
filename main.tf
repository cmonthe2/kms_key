


#!/bin/bash

set -e

# Set AWS CLI profile and region
export AWS_PROFILE=default


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
    POLICY_JSON=$(aws kms get-key-policy --key-id "$KEY_ID" --policy-name default | jq -r '.Policy')

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

    jq -c '.Statement[]' <<< "$POLICY_JSON" | while read -r stmt; do
      SID=$(echo "$stmt" | jq -r '.Sid // empty')
      EFFECT=$(echo "$stmt" | jq -r '.Effect')
      ACTIONS=$(echo "$stmt" | jq -r '.Action | if type=="string" then [.] else . end | @sh')
      RESOURCES=$(echo "$stmt" | jq -r '.Resource | if type=="string" then [.] else . end | @sh')
      PRINCIPALS=$(echo "$stmt" | jq -c '.Principal // empty')
      CONDITION=$(echo "$stmt" | jq -c '.Condition // empty')

      echo "  statement {" >> aws_kms_policy_document.tf
      [[ -n "$SID" ]] && echo "    sid    = \"$SID\"" >> aws_kms_policy_document.tf
      echo "    effect = \"$EFFECT\"" >> aws_kms_policy_document.tf
      echo "    actions = $(eval echo $ACTIONS | sed 's/ /\", \"/g' | sed 's/^/\[/;s/$/\]/')" >> aws_kms_policy_document.tf
      echo "    resources = $(eval echo $RESOURCES | sed 's/ /\", \"/g' | sed 's/^/\[/;s/$/\]/')" >> aws_kms_policy_document.tf

      if [[ "$PRINCIPALS" != "null" && -n "$PRINCIPALS" ]]; then
        for ptype in $(echo "$PRINCIPALS" | jq -r 'keys[]'); do
          IDS=$(echo "$PRINCIPALS" | jq -r --arg p "$ptype" '.[$p] | if type=="string" then [.] else . end | @sh')
          echo "    principals {" >> aws_kms_policy_document.tf
          echo "      type        = \"$ptype\"" >> aws_kms_policy_document.tf
          echo "      identifiers = $(eval echo $IDS | sed 's/ /\", \"/g' | sed 's/^/\[/;s/$/\]/')" >> aws_kms_policy_document.tf
          echo "    }" >> aws_kms_policy_document.tf
        done
      fi

      if [[ "$CONDITION" != "null" && -n "$CONDITION" ]]; then
        for condition_operator in $(echo "$CONDITION" | jq -r 'keys[]'); do
          echo "    condition {" >> aws_kms_policy_document.tf
          echo "      test     = \"$condition_operator\"" >> aws_kms_policy_document.tf
          for condition_key in $(echo "$CONDITION" | jq -r --arg op "$condition_operator" '.[$op] | keys[]'); do
            echo "      variable = \"$condition_key\"" >> aws_kms_policy_document.tf
            VALUES=$(echo "$CONDITION" | jq -r --arg op "$condition_operator" --arg key "$condition_key" '.[$op][$key] | if type=="string" then [.] else . end | @sh')
            echo "      values   = $(eval echo $VALUES | sed 's/ /\", \"/g' | sed 's/^/\[/;s/$/\]/')" >> aws_kms_policy_document.tf
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

echo "✅ Done: Fully normalized HCL policies written in $(pwd)"












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

