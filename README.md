# Basic usage

python3 sns_to_terraform.py

Create a new env
python3 -m venv .venv

# Activate it
source .venv/bin/activate

# Install required packages
pip3 install boto3

# Run your script
python sns_to_terraform.py


 cd module then run terraform init

 run the cmd in import.py


python3 kms-import-script.py --region us-east-1

# Using a specific AWS profile
python3 kms-import-script.py --region us-east-1 --profile my-profile

# Create a module structure too
python3 kms-import-script.py --region us-east-1 --create-module

# Specify output directory
python3 kms-import-script.py --region us-east-1 --output-dir my-terraform-dir


python3 kms-import-script.py --region us-east-1
