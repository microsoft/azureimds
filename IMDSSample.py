#!/usr/bin/env python3
import json
import urllib.request
import sys


mdUrl = "http://169.254.169.254/metadata/instance?api-version=2017-04-02"
header={'Metadata': 'True'}
request = urllib.request.Request(url=mdUrl, headers=header) 
response = urllib.request.urlopen(request)
data = response.read()
dataStr = data.decode("utf-8")

jsonObj = json.loads(dataStr)

print(json.dumps(jsonObj, sort_keys=True, indent=4, separators=(',', ': ')))