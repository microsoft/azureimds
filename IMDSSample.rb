require 'open-uri'
require 'json'

url_metadata="http://169.254.169.254/metadata/instance?api-version=2019-04-30"

puts open(url_metadata,"Metadata"=>"true").read