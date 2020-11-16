#!/usr/bin/env python3

import base64
import json
import re
import subprocess

import requests

imds_server_base_url = "http://169.254.169.254"

instance_api_version = "2019-03-11"
instance_endpoint = imds_server_base_url + "/metadata/instance?api-version=" + instance_api_version

attested_api_version = "2019-03-11"
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
    print("Attested provider validation:")
    attested_signature = attested_json['signature']
    validate_attested_data(attested_signature)
    validate_attested_cert(attested_signature)

def find_phrase_in_file(filename, phrase):
    file = open(filename, "r")
    for line in file:
        if re.search(phrase, line):
           return line

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
    print("Cert chain validation.")
    # We use the subprocess module to call OpenSSL for cert manipulation as PyOpenSSL is missing implementations of these commands.
    # First, we base64 decode the signature using the OpenSSL decoder, which works better with subsequent OpenSSL commands than the Python base64 decoder.
    subprocess.call("openssl enc -base64 -d -A < signature > decoded_signature", shell=True)
    # We obtain information about the signer from the decoded signature.
    subprocess.call("openssl pkcs7 -in decoded_signature -inform DER  -print_certs -out signer.pem", shell=True)
    # We parse out the intermediate cert URL; then, we download the intermediate cert for verification.
    subprocess.call("openssl x509 -in signer.pem -text -noout > cert_info", shell=True)
    intermediate_cert_url = find_phrase_in_file("cert_info", "CA Issuers").split("URI:", 1)[1]
    r = requests.get(intermediate_cert_url)
    with open('intermediate.cer', 'wb') as f:
        f.write(r.content)
    subprocess.call("openssl x509 -inform der -in intermediate.cer -out intermediate.pem", shell=True)
    # We, finally, verify the complete cert chain.
    subprocess.call("openssl verify -verbose -CAfile /etc/ssl/certs/Baltimore_CyberTrust_Root.pem -untrusted intermediate.pem signer.pem", shell=True)

# Ensure the nonce in the response is the same as the one we supplied. Use similar logic to validate other information such as subscriptionId.
def validate_attested_data(attested_signature):
    decoded_attested_data = decode_attested_data(attested_signature)
    if attested_nonce in decoded_attested_data:
        print("Nonce values match.")

if __name__ == "__main__":
    main()
