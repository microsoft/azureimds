require 'base64'
require 'openssl'
require 'open-uri'
require 'json'

# change path to the directory where your certs are
CERT_PATH = '/etc/ssl/certs/'.freeze
URL_METADATA = 'http://169.254.169.254/metadata/attested/document?api-version=2025-04-07'.freeze

# Proxies must be bypassed when calling Azure IMDS
# depending on your Ruby version you can do URI.open instead of open
metadata = open(URL_METADATA, 'Metadata' => 'true', :proxy => nil).read
parsed_metadata = JSON.parse(metadata)

signature = parsed_metadata['signature']
decoded_signature = Base64.decode64(signature)

p7 = OpenSSL::PKCS7.new(decoded_signature)
cert = p7.certificates[0]
extensions = cert.extensions

ca_issuers = extensions.select { |ext| ext.value.include? 'CA Issuers' }
unless ca_issuers.length && ca_issuers[0].value.split('\n').length
  puts 'No CA Issuers found'
  return
end
ca_value = ca_issuers[0].value.split("\n")[0]
url_intermediate_cert = ca_value[ca_value.index('http'), ca_value.index('crt')]
# depending on your Ruby version you can do URI.open instead of open
intermediate_cert_content = open(url_intermediate_cert).read
intermediate_pem = OpenSSL::X509::Certificate.new intermediate_cert_content

store = OpenSSL::X509::Store.new
if p7.verify([cert], store, nil, OpenSSL::PKCS7::NOVERIFY)
  puts 'Verification successful'
  puts p7.data
end
puts
puts 'Verify main certificate subject and issuer'
puts "subject= #{cert.subject.to_s[1..-1].gsub!("/", ' ').strip.gsub!(' ', ', ').gsub!('=', ' = ')}"
puts "issuer = #{cert.issuer.to_s[1..-1].gsub!("/", ', ').strip.gsub!('=', ' = ')}"
puts
puts 'Validate intermediate certificate and issuer'
puts "subject= #{intermediate_pem.subject.to_s[1..-1].gsub!("/", ', ').strip.gsub!('=', ' = ')}"
puts "issuer = #{intermediate_pem.issuer.to_s[1..-1].gsub!("/", ', ').strip.gsub!('=', ' = ')}"
puts
name = OpenSSL::X509::Name.parse(intermediate_pem.issuer.to_s)
name = name.to_s.split("/")
cn = name.select { |el| el.include?('CN') }
# in case your certs have underscores instead of spaces
root_pem = cn[0].split('=')[1].gsub!(' ', '_')
puts 'Certificate chain'
ca = OpenSSL::X509::Certificate.new(File.read(File.join(CERT_PATH, "#{root_pem}.pem")))
puts 'failed' unless intermediate_pem.verify(ca.public_key) && cert.verify(intermediate_pem.public_key)

puts 'signer.pem: OK'
