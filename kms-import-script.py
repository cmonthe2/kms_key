#!/usr/bin/env python3
import boto3
import json
import os
import argparse
from botocore.exceptions import ClientError

def get_kms_keys(region, profile=None):
    """Get all KMS keys in the specified region"""
    session = boto3.Session(profile_name=profile, region_name=region)
    kms_client = session.client('kms')
    
    try:
        # List all keys
        paginator = kms_client.get_paginator('list_keys')
        keys = []
        
        for page in paginator.paginate():
            keys.extend(page['Keys'])
        
        # Get detailed information for each key
        detailed_keys = []
        for key in keys:
            key_id = key['KeyId']
            try:
                # Get key details
                key_details = kms_client.describe_key(KeyId=key_id)
                
                # Skip AWS managed keys if needed
                if key_details['KeyMetadata'].get('KeyManager') == 'AWS':
                    continue
                
                # Get aliases for this key
                aliases_response = kms_client.list_aliases(KeyId=key_id)
                aliases = aliases_response.get('Aliases', [])
                
                # Get key policy
                policy_response = kms_client.get_key_policy(KeyId=key_id, PolicyName='default')
                policy = json.loads(policy_response['Policy'])
                
                # Get tags if any
                try:
                    tags_response = kms_client.list_resource_tags(KeyId=key_id)
                    tags = tags_response.get('Tags', [])
                except ClientError:
                    tags = []
                
                # Add all info to our detailed keys list
                detailed_keys.append({
                    'KeyMetadata': key_details['KeyMetadata'],
                    'Aliases': aliases,
                    'Policy': policy,
                    'Tags': tags
                })
                
            except ClientError as e:
                print(f"Error getting details for key {key_id}: {e}")
                continue
        
        return detailed_keys
    
    except ClientError as e:
        print(f"Error listing KMS keys: {e}")
        return []

def generate_terraform_config(keys, output_dir):
    """Generate Terraform configuration for KMS keys"""
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Create main.tf for the KMS resources
    main_tf_path = os.path.join(output_dir, 'main.tf')
    import_script_path = os.path.join(output_dir, 'import-keys.sh')
    
    with open(main_tf_path, 'w') as main_tf, open(import_script_path, 'w') as import_script:
        # Add shebang to import script
        import_script.write('#!/bin/bash\n\n')
        
        # Write provider block
        main_tf.write('provider "aws" {\n  region = "' + keys[0]['KeyMetadata']['Arn'].split(':')[3] + '"\n}\n\n')
        
        for key_data in keys:
            key_metadata = key_data['KeyMetadata']
            key_id = key_metadata['KeyId']
            key_arn = key_metadata['Arn']
            
            # Create a Terraform resource name (sanitized)
            resource_name = f"key_{key_id.replace('-', '_')}"
            
            # Write the KMS key resource
            main_tf.write(f'resource "aws_kms_key" "{resource_name}" {{\n')
            main_tf.write(f'  description             = "{key_metadata.get("Description", "Imported KMS Key")}"\n')
            main_tf.write(f'  deletion_window_in_days = 30\n')  # Default - adjust as needed
            main_tf.write(f'  key_usage               = "{key_metadata.get("KeyUsage", "ENCRYPT_DECRYPT")}"\n')
            
            if 'MultiRegion' in key_metadata:
                main_tf.write(f'  multi_region = {str(key_metadata["MultiRegion"]).lower()}\n')
            
            if key_metadata.get('CustomerMasterKeySpec'):
                main_tf.write(f'  customer_master_key_spec = "{key_metadata["CustomerMasterKeySpec"]}"\n')
            
            if key_metadata.get('KeyState') != 'Enabled':
                main_tf.write(f'  is_enabled = false\n')
            
            # Write the policy
            policy_json = json.dumps(key_data['Policy'], indent=2)
            main_tf.write(f'  policy = <<POLICY\n{policy_json}\nPOLICY\n')
            
            # Write tags if any
            if key_data['Tags']:
                main_tf.write('  tags = {\n')
                for tag in key_data['Tags']:
                    main_tf.write(f'    {tag["TagKey"]} = "{tag["TagValue"]}"\n')
                main_tf.write('  }\n')
            
            main_tf.write('}\n\n')
            
            # Write aliases if any
            for alias in key_data['Aliases']:
                alias_name = alias['AliasName']
                alias_resource_name = f"alias_{alias_name.replace('alias/', '').replace('-', '_').replace('/', '_')}"
                
                main_tf.write(f'resource "aws_kms_alias" "{alias_resource_name}" {{\n')
                main_tf.write(f'  name          = "{alias_name}"\n')
                main_tf.write(f'  target_key_id = aws_kms_key.{resource_name}.key_id\n')
                main_tf.write('}\n\n')
                
                # Write import command for alias
                import_script.write(f'terraform import aws_kms_alias.{alias_resource_name} {alias_name}\n')
            
            # Write import command for key
            import_script.write(f'terraform import aws_kms_key.{resource_name} {key_arn}\n\n')
    
    # Make the import script executable
    os.chmod(import_script_path, 0o755)
    
    print(f"Terraform configuration written to {main_tf_path}")
    print(f"Import script written to {import_script_path}")

def generate_module_structure(output_dir):
    """Generate a reusable KMS module structure"""
    module_dir = os.path.join(output_dir, 'modules', 'kms')
    
    if not os.path.exists(module_dir):
        os.makedirs(module_dir)
    
    # Create main.tf
    with open(os.path.join(module_dir, 'main.tf'), 'w') as f:
        f.write('''resource "aws_kms_key" "key" {
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
''')
    
    # Create variables.tf
    with open(os.path.join(module_dir, 'variables.tf'), 'w') as f:
        f.write('''variable "description" {
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
''')
    
    # Create outputs.tf
    with open(os.path.join(module_dir, 'outputs.tf'), 'w') as f:
        f.write('''output "key_id" {
  description = "The globally unique identifier for the key"
  value       = aws_kms_key.key.id
}

output "key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = aws_kms_key.key.arn
}

output "alias_arn" {
  description = "The Amazon Resource Name (ARN) of the key alias"
  value       = length(aws_kms_alias.alias) > 0 ? aws_kms_alias.alias[0].arn : null
}
''')
    
    # Create example usage file
    with open(os.path.join(output_dir, 'module_example.tf'), 'w') as f:
        f.write('''module "encryption_key" {
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
''')
    
    print(f"Module structure created in {module_dir}")
    print(f"Module usage example written to {os.path.join(output_dir, 'module_example.tf')}")

def main():
    parser = argparse.ArgumentParser(description='Import KMS keys to Terraform')
    parser.add_argument('--region', required=True, help='AWS region')
    parser.add_argument('--profile', help='AWS profile')
    parser.add_argument('--output-dir', default='terraform-kms', help='Output directory for Terraform files')
    parser.add_argument('--create-module', action='store_true', help='Create a reusable KMS module')
    
    args = parser.parse_args()
    
    print(f"Retrieving KMS keys from region {args.region}...")
    keys = get_kms_keys(args.region, args.profile)
    
    if not keys:
        print("No customer managed KMS keys found.")
        return
    
    print(f"Found {len(keys)} customer managed KMS keys.")
    generate_terraform_config(keys, args.output_dir)
    
    if args.create_module:
        generate_module_structure(args.output_dir)

if __name__ == "__main__":
    main()