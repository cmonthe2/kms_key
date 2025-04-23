
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



Traceback (most recent call last):
  File "/Users/cmonthe/workspace/terraform/alias.py", line 12, in <module>
    response = kms.get_key_policy(KeyId=KEY_ID, PolicyName="default")
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/client.py", line 570, in _api_call
    return self._make_api_call(operation_name, kwargs)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/context.py", line 124, in wrapper
    return func(*args, **kwargs)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/client.py", line 1013, in _make_api_call
    http, parsed_response = self._make_request(
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/client.py", line 1037, in _make_request
    return self._endpoint.make_request(operation_model, request_dict)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/endpoint.py", line 119, in make_request
    return self._send_request(request_dict, operation_model)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/endpoint.py", line 196, in _send_request
    request = self.create_request(request_dict, operation_model)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/endpoint.py", line 132, in create_request
    self._event_emitter.emit(
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/hooks.py", line 412, in emit
    return self._emitter.emit(aliased_event_name, **kwargs)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/hooks.py", line 256, in emit
    return self._emit(event_name, kwargs)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/hooks.py", line 239, in _emit
    response = handler(**kwargs)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/signers.py", line 106, in handler
    return self.sign(operation_name, request)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/signers.py", line 189, in sign
    auth = self.get_auth_instance(**kwargs)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/signers.py", line 307, in get_auth_instance
    frozen_credentials = credentials.get_frozen_credentials()
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/credentials.py", line 664, in get_frozen_credentials
    self._refresh()
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/credentials.py", line 551, in _refresh
    self._protected_refresh(is_mandatory=is_mandatory_refresh)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/credentials.py", line 567, in _protected_refresh
    metadata = self._refresh_using()
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/credentials.py", line 716, in fetch_credentials
    return self._get_cached_credentials()
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/credentials.py", line 726, in _get_cached_credentials
    response = self._get_credentials()
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/credentials.py", line 2253, in _get_credentials
    response = client.get_role_credentials(**kwargs)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/client.py", line 570, in _api_call
    return self._make_api_call(operation_name, kwargs)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/context.py", line 124, in wrapper
    return func(*args, **kwargs)
  File "/Users/cmonthe/Library/Python/3.9/lib/python/site-packages/botocore/client.py", line 1031, in _make_api_call
    raise error_class(parsed_response, operation_name)
botocore.exceptions.ClientError: An error occurred (ForbiddenException) when calling the GetRoleCredentials operation: No access
➜  terraform                                                                                                                        
