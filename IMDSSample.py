#!/usr/bin/env python3
import json
import requests

endpoint = "http://169.254.169.254/metadata/instance?api-version=2019-04-30"
headers={'Metadata': 'True'}

json_obj = requests.get(endpoint, headers=headers).json()

print(json.dumps(json_obj, sort_keys=True, indent=4, separators=(',', ': ')))
