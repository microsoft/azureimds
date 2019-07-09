#!/usr/bin/env python3

import base64
import json
import subprocess

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
    validate_attested_cert(attested_signature)

# Base-64 decode the string
def decode_attested_data(attested_signature):
    decoded_string = base64.b64decode(attested_signature).decode('utf-8', 'replace')
    return decoded_string

def pretty_print_json_obj_to_terminal(json_obj):
    print(json.dumps(json_obj, sort_keys=True, indent=4, separators=(',', ': ')))

# Build the cert chain for validation
def validate_attested_cert(attested_signature):
    # Dump PKCS7, base64 encoded signature to file.
    file = open("signature", "w")
    file.write(attested_signature)
    file.close()
    # We use the subprocess module to call OpenSSL for cert manipulation as PyOpenSSL is missing a lot of these commands.
    subprocess.call("./VerifySignature.sh", shell=True)

# Ensure the nonce in the response is the same as the one we supplied
def validate_attested_data(attested_signature):
    decoded_attested_data = decode_attested_data(attested_signature)
    if attested_nonce in decoded_attested_data:
        print("Nonce values match")

if __name__ == "__main__":
    main()
