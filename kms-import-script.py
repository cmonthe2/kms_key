#!/usr/bin/env python3
import boto3
import json
import os
import argparse
from datetime import datetime

def datetime_converter(o):
    """Helper function to convert datetime objects to strings for JSON serialization"""
    if isinstance(o, datetime):
        return o.isoformat()
    raise TypeError(f"Object of type {type(o)} is not JSON serializable")

def main():
    # Add command-line argument parsing for AWS profile
    parser = argparse.ArgumentParser(description='Create Terraform configuration for existing KMS keys')
    parser.add_argument('--profile', type=str, default='default',
                        help='AWS profile to use (default: default)')
    args = parser.parse_args()
    
    # Initialize boto3 session with the specified profile
    session = boto3.Session(profile_name=args.profile)
    
    # Initialize boto3 client for KMS using the session
    kms_client = session.client('kms')
    
    print(f"Using AWS profile: {args.profile}")
    
    # Create directory for output files if it doesn't exist
    output_dir = "terraform-kms-import"
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    # Create module directory structure
    modules_dir = os.path.join(output_dir, "modules")
    kms_module_dir = os.path.join(modules_dir, "kms")
    os.makedirs(kms_module_dir, exist_ok=True)
    
    # Get list of all KMS keys in the account
    keys = []
    response = kms_client.list_keys()
    keys.extend(response['Keys'])
    
    while response.get('Truncated', False):
        response = kms_client.list_keys(Marker=response['NextMarker'])
        keys.extend(response['Keys'])
    
    print(f"Found {len(keys)} KMS keys in your account.")
    
    # Create module files
    module_main_tf_path = os.path.join(kms_module_dir, "main.tf")
    module_variables_tf_path = os.path.join(kms_module_dir, "variables.tf")
    module_outputs_tf_path = os.path.join(kms_module_dir, "outputs.tf")
    
    # Create root module files
    root_main_tf_path = os.path.join(output_dir, "main.tf")
    root_variables_tf_path = os.path.join(output_dir, "variables.tf")
    root_outputs_tf_path = os.path.join(output_dir, "outputs.tf")
    providers_tf_path = os.path.join(output_dir, "providers.tf")
    terraform_tf_path = os.path.join(output_dir, "terraform.tf")
    
    # Create import script
    import_script_path = os.path.join(output_dir, "import-keys.sh")
    
    # Variables for our files
    module_main_content = ""
    module_variables_content = """
variable "description" {
  description = "The description of the KMS key"
  type        = string
  default     = "KMS key for encryption"
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

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

variable "aliases" {
  description = "A list of aliases to create for the key"
  type        = list(string)
  default     = []
}
"""

    module_outputs_content = """
output "key_id" {
  description = "The globally unique identifier for the key"
  value       = aws_kms_key.this.key_id
}

output "key_arn" {
  description = "The Amazon Resource Name (ARN) of the key"
  value       = aws_kms_key.this.arn
}

output "aliases" {
  description = "A list of all aliases for the key"
  value       = [for a in aws_kms_alias.this : a.name]
}
"""

    # Create KMS module main.tf
    module_main_content = """
resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = var.enable_key_rotation
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  for_each      = toset(var.aliases)
  name          = each.value
  target_key_id = aws_kms_key.this.key_id
}
"""

    # Create providers.tf - now with profile variable uncommented
    providers_content = """
provider "aws" {
  region = var.aws_region
  
  # Profile is now included by default
  profile = var.aws_profile
}
"""

    # Create terraform.tf
    terraform_content = """
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  required_version = ">= 1.0.0"
}
"""

    # Create root variables.tf - now with profile variable uncommented
    root_variables_content = """
variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# AWS profile variable is now uncommented and set to the profile used for script execution
variable "aws_profile" {
  description = "The AWS profile to use"
  type        = string
  default     = "%s"
}
""" % args.profile

    # Write shared module files
    with open(module_main_tf_path, 'w') as f:
        f.write(module_main_content)
    
    with open(module_variables_tf_path, 'w') as f:
        f.write(module_variables_content)
    
    with open(module_outputs_tf_path, 'w') as f:
        f.write(module_outputs_content)
    
    # Write root module shared files
    with open(providers_tf_path, 'w') as f:
        f.write(providers_content)
    
    with open(terraform_tf_path, 'w') as f:
        f.write(terraform_content)
    
    with open(root_variables_tf_path, 'w') as f:
        f.write(root_variables_content)
    
    # Initialize import commands
    import_commands = "#!/bin/bash\n\n"
    root_main_content = ""
    root_outputs_content = ""
    
    # Process each key to create module instances in the root module
    for key in keys:
        key_id = key['KeyId']
        
        # Get detailed information about the key
        try:
            key_info = kms_client.describe_key(KeyId=key_id)
            # Skip AWS managed keys as they cannot be imported into Terraform
            if key_info['KeyMetadata'].get('KeyManager') == 'AWS':
                print(f"Skipping AWS managed key: {key_id}")
                continue
                
            # Get key aliases
            alias_response = kms_client.list_aliases(KeyId=key_id)
            aliases = alias_response.get('Aliases', [])
            
            # Get key tags
            try:
                tag_response = kms_client.list_resource_tags(KeyId=key_id)
                tags = tag_response.get('Tags', [])
            except Exception as e:
                print(f"Could not get tags for key {key_id}: {e}")
                tags = []
            
            # Generate a resource name based on key ID
            # Replace dashes with underscores for valid Terraform identifiers
            resource_name = f"key_{key_id.replace('-', '_')}"
            
            # Get key rotation status
            try:
                rotation_response = kms_client.get_key_rotation_status(KeyId=key_id)
                key_rotation_enabled = rotation_response.get('KeyRotationEnabled', False)
            except Exception as e:
                print(f"Could not get rotation status for key {key_id}: {e}")
                key_rotation_enabled = False
            
            # Create module instance in root main.tf
            module_instance = f"""
module "{resource_name}" {{
  source = "./modules/kms"
  
  description             = "{key_info['KeyMetadata'].get('Description', 'Imported KMS key')}"
  deletion_window_in_days = 30
  enable_key_rotation     = {str(key_rotation_enabled).lower()}
"""
            
            # Add tags if any
            if tags:
                module_instance += "  tags = {\n"
                for tag in tags:
                    module_instance += f'    {tag["TagKey"]} = "{tag["TagValue"]}"\n'
                module_instance += "  }\n"
            
            # Add aliases if any
            if aliases:
                module_instance += "  aliases = [\n"
                for alias in aliases:
                    module_instance += f'    "{alias["AliasName"]}",\n'
                module_instance += "  ]\n"
            
            module_instance += "}\n"
            
            # Add outputs for this key
            root_outputs_content += f"""
output "{resource_name}_key_id" {{
  description = "The ID of the {resource_name} key"
  value       = module.{resource_name}.key_id
}}

output "{resource_name}_key_arn" {{
  description = "The ARN of the {resource_name} key"
  value       = module.{resource_name}.key_arn
}}
"""
            
            root_main_content += module_instance
            
            # Create import command for the key
            import_commands += f"terraform import 'module.{resource_name}.aws_kms_key.this' {key_id}\n"
            
            # Add import commands for aliases
            for i, alias in enumerate(aliases):
                alias_name = alias['AliasName']
                import_commands += f"terraform import 'module.{resource_name}.aws_kms_alias.this[\"{alias_name}\"]' {alias_name}\n"
            
            # Save detailed key information to a JSON file for reference
            key_info_path = os.path.join(output_dir, f"{key_id}.json")
            with open(key_info_path, 'w') as f:
                json.dump(key_info, f, default=datetime_converter, indent=2)
            
            print(f"Processed key: {key_id}")
            
        except Exception as e:
            print(f"Error processing key {key_id}: {e}")
    
    # Write root main.tf
    with open(root_main_tf_path, 'w') as f:
        f.write(root_main_content)
    
    # Write root outputs.tf
    with open(root_outputs_tf_path, 'w') as f:
        f.write(root_outputs_content)
    
    # Write import commands to import script and make it executable
    with open(import_script_path, 'w') as f:
        f.write(import_commands)
    
    os.chmod(import_script_path, 0o755)
    
    print(f"\nTerraform module structure created in {output_dir}/")
    print(f"Import commands written to {import_script_path}")
    print(f"\nTo import the keys, run:")
    print(f"  cd {output_dir}")
    print(f"  terraform init")
    print(f"  ./import-keys.sh")
    print(f"\nThe Terraform configuration is set to use the AWS profile: {args.profile}")

if __name__ == "__main__":
    main()
