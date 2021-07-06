$ImdsServer = "http://169.254.169.254"
$InstanceEndpoint = $ImdsServer + "/metadata/instance"
$AttestedEndpoint = $ImdsServer + "/metadata/attested/document"
$NonceValue = "123456"

# Use of -NoProxy requires use of PowerShell V6 or greater. If you use an older version of PowerShell,
# consider using examples like:
#
# $request = [System.Net.WebRequest]::Create("http://169.254.169.254/metadata/instance?api-version=2019-02-01")
# $request.Proxy = [System.Net.WebProxy]::new()
# $request.Headers.Add("Metadata","True")
# $request.GetResponse()
#
# or:
#
# $Proxy=New-object System.Net.WebProxy
# $WebSession=new-object Microsoft.PowerShell.Commands.WebRequestSession
# $WebSession.Proxy=$Proxy
# Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Uri "http://169.254.169.254/metadata/instance?api-version=2021-02-01" -WebSession $WebSession

function Query-InstanceEndpoint
{
    $uri = $InstanceEndpoint + "?api-version=2019-03-11"
    $result = Invoke-RestMethod -Method GET -NoProxy -Uri $uri -Headers @{"Metadata"="True"}
    return $result
}

function Query-AttestedEndpoint
{
    $uri = $AttestedEndpoint + "?api-version=2019-03-11&nonce=" + $NonceValue
    $result = Invoke-RestMethod -Method GET -NoProxy -Uri $uri -Headers @{"Metadata"="True"}
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
