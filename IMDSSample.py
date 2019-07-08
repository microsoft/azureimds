#!/usr/bin/env python3
from Crypto.Cipher import AES
from pkcs7 import PKCS7Encoder

import base64
import json
import requests

imds_server_base_url = "http://169.254.169.254"

instance_api_version = "2017-08-01"
instance_endpoint = imds_server_base_url + "/metadata/instance?api-version=" + instance_api_version

attested_api_version = "2019-04-30"
attested_nonce = "1234576"
attested_endpoint = imds_server_base_url + "/metadata/attested/document?api-version=" + attested_api_version + "&nonce=" + attested_nonce

def api_call(endpoint):
    headers={'Metadata': 'True'}
    json_obj = requests.get(endpoint, headers=headers).json()
    return json_obj

def main():
    # Instance provider API call
    instance_json = api_call(instance_endpoint)
    print("Instance provider data:")
    pretty_print_json_obj_to_terminal(instance_json)

    # Attested provider API call
    attested_json = api_call(attested_endpoint)
    print("Attested provider data:")
    attested_signature = attested_json['signature']
    validate_attested_data(attested_signature)

def parse_attested_data(attested_signature):
    decoded_string = base64.b64decode(attested_signature).decode('utf-8', 'replace')
    return decoded_string

def pretty_print_json_obj_to_terminal(json_obj):
    print(json.dumps(json_obj, sort_keys=True, indent=4, separators=(',', ': ')))

# Ensure the nonce in the response is the same as the one we supplied
def validate_attested_data(attested_signature):
    parsed_attested_data = parse_attested_data(attested_signature)
    if attested_nonce in parsed_attested_data:
        print("Nonce values match")

if __name__ == "__main__":
    main()
