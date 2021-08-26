require 'open-uri'
require 'json'

url_metadata="http://169.254.169.254/metadata/instance?api-version=2021-02-01"

# Proxies must be bypassed when calling Azure IMDS
puts open(url_metadata,"Metadata"=>"true", :proxy => nil).read