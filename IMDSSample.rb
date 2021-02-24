require 'open-uri'
require 'json'

url_metadata="http://169.254.169.254/metadata/instance?api-version=2019-03-11"

puts open(url_metadata,"Metadata"=>"true", :proxy => nil).read