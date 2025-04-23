# Basic usage
python3 kms-import-script.py --region us-east-1

# Using a specific AWS profile
python3 kms-import-script.py --region us-east-1 --profile my-profile

# Create a module structure too
python3 kms-import-script.py --region us-east-1 --create-module

# Specify output directory
python3 kms-import-script.py --region us-east-1 --output-dir my-terraform-dir


python3 kms-import-script.py --region us-west-2

LIST OF KEYS 
aws kms list-keys --region us-east-1


[profile d2c-non-prod]
sso_session = rb
sso_account_id = 12334444444
sso_role_name = AWS-SSO-me
region = us-west-2
output = json
sso_region = us-west-2

[sso-session eig]
 
sso_start_url = https://d-ffr5555.awsapps.com/start/#
 
sso_region = us-west-2
 
sso_registration_scopes = sso:account:access



for key in $(aws kms list-keys --query 'Keys[*].KeyId' --output text); do
  manager=$(aws kms describe-key --key-id "$key" --query 'KeyMetadata.KeyManager' --output text)
  if [ "$manager" == "CUSTOMER" ]; then
    echo "$key"
    aws kms list-aliases --query "Aliases[?TargetKeyId=='$key'].AliasName" --output text
  fi
done > included_resources.txt
