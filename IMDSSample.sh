sudo apt-get install curl
sudo apt-get jq
# Instance call
curl -H Metadata:True "http://169.254.169.254/metadata/instance?api-version=2017-04-02&format=json" | jq .
# Make Attested call and extract signature
curl  --silent -H Metadata:True http://169.254.169.254/metadata/attested/document?api-version=2018-10-01 | jq -r '.["signature"]' > signature
# Decode the signature
base64 -d signature > decodedsignature
#Get PKCS7 format
openssl pkcs7 -in decodedsignature -inform DER -out sign.pk7
# Get Public key out of pkc7
openssl pkcs7 -in decodedsignature -inform DER  -print_certs -out signer.pem
#Get the intermediate certificate
wget -q -O intermediate.cer "$(openssl x509 -in signer.pem -text -noout | grep " CA Issuers -" | awk -FURI: '{print $2}')"
openssl x509 -inform der -in intermediate.cer -out intermediate.pem
#Verify the contents
openssl smime -verify -in sign.pk7 -inform pem -noverify
echo "Verify main certificate subject and issuer"
# Verify the subject name for the main certificate
openssl x509 -noout -subject -in signer.pem
# Verify the issuer for the main certificate
openssl x509 -noout -issuer -in signer.pem
echo "Validate intermediate certificate and issuer "
#Validate the subject name for intermediate certificate
openssl x509 -noout -subject -in intermediate.pem
# Verify the issuer for the intermediate certificate
openssl x509 -noout -issuer -in intermediate.pem
echo "Certificate chain "
# Verify the certificate chain
openssl verify -verbose -CAfile /etc/ssl/certs/Baltimore_CyberTrust_Root.pem -untrusted intermediate.pem signer.pem