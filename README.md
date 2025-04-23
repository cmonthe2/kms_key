
import boto3
import json

AWS_PROFILE = "default"  # Change if needed
KEY_ID = "1234abcd-5678-efgh-9012-ijklmnopqrst"  # Replace with your actual KMS Key ID
RESOURCE_NAME = "monthly_key"

session = boto3.Session(profile_name=AWS_PROFILE)
kms = session.client('kms')

# Fetch the actual key policy
response = kms.get_key_policy(KeyId=KEY_ID, PolicyName="default")
policy_json = json.loads(response["Policy"])

# Generate Terraform block
print(f'resource "aws_kms_key_policy" "{RESOURCE_NAME}_policy" {{')
print(f'  key_id = aws_kms_key.{RESOURCE_NAME}.key_id')
print('  policy = jsonencode(')
print(json.dumps(policy_json, indent=2))
print('  )')
print('}')


python3 kms-import-script.py --region us-east-1

# Using a specific AWS profile
python3 kms-import-script.py --region us-east-1 --profile my-profile

# Create a module structure too
python3 kms-import-script.py --region us-east-1 --create-module

# Specify output directory
python3 kms-import-script.py --region us-east-1 --output-dir my-terraform-dir


python3 kms-import-script.py --region us-east-1
