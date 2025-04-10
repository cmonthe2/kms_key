#!/bin/bash

terraform import aws_kms_alias.alias_monthe alias/monthe
terraform import aws_kms_key.key_f7fd450e_22b4_4c71_babc_debdcf8b4803 arn:aws:kms:us-east-1:204469479814:key/f7fd450e-22b4-4c71-babc-debdcf8b4803

