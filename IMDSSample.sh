sudo apt-get install curl
sudo apt-get jq
# Instance call
curl -H Metadata:True "http://169.254.169.254/metadata/instance?api-version=2017-04-02&format=json" | jq .
# Make Attested call and extract signature
curl  --silent -H Metadata:True http://169.254.169.254/metadata/attested/document?api-version=2018-10-01 | jq -r '.["signature"]' > signature
./VerifySignature.sh