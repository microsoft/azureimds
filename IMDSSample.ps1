$ImdsServer = "http://169.254.169.254"
$InstanceEndpoint = $ImdsServer + "/metadata/instance"
$AttestedEndpoint = $ImdsServer + "/metadata/attested/document"
$NonceValue = "123456"

function Query-InstanceEndpoint
{
    $uri = $InstanceEndpoint + "?api-version=2018-10-01"
    $result = Invoke-RestMethod -Method GET -Uri $uri -Headers @{"Metadata"="True"}
    return $result
}

function Query-AttestedEndpoint
{
    $uri = $AttestedEndpoint + "?api-version=2019-04-30&nonce=" + $NonceValue
    $result = Invoke-RestMethod -Method GET -Uri $uri -Headers @{"Metadata"="True"}
    return $result
}

function Parse-AttestedResponse
{
    param
    (
        [PSObject]$response
    )
    $signature = $response.signature
    Validate-AttestedCertificate $signature
    Validate-AttestedData $signature
}

function Validate-AttestedCertificate
{
    param
    (
        [string]$signature
    )
    $decoded = [System.Convert]::FromBase64String($signature)
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]($decoded)
    $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    $result = $chain.Build($cert)
    foreach($element in $chain.ChainElements)
    {
        $element.Certificate | Format-List *
    }
}

function Validate-AttestedData
{
    param
    (
        [string]$signature
    )
    $decoded = [System.Convert]::FromBase64String($signature)
    $signedCms = New-Object -TypeName System.Security.Cryptography.Pkcs.SignedCms
    $signedCms.Decode($decoded);
    $content = [System.Text.Encoding]::UTF8.GetString($signedCms.ContentInfo.Content)
    Write-Host "Attested data: " $content
    $json = $content | ConvertFrom-Json
    $nonce = $json.nonce
    if($nonce.Equals($NonceValue))
    {
        Write-Host "Nonce values match"
    }
}

# Make Instance call and print the response
$result = Query-InstanceEndpoint
$result | ConvertTo-JSON -Depth 99

# Make Attested call and parse the response
$result = Query-AttestedEndpoint
Parse-AttestedResponse $result
