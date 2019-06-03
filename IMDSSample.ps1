$ImdsServer = "http://169.254.169.254"
$InstanceEndpoint = $ImdsServer + "/metadata/instance"
$AttestedEndpoint = $ImdsServer + "/metadata/attested/document"

function Query-InstanceEndpoint
{
    $uri = $InstanceEndpoint + "?api-version=2018-10-01"
    $result = Invoke-RestMethod -Method GET -Uri $uri -Headers @{"Metadata"="True"}
    return $result
}

function Query-AttestedEndpoint
{
    $uri = $AttestedEndpoint + "?api-version=2018-10-01"
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
    $decoded = [System.Convert]::FromBase64String($signature)
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]($decoded)
    $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    $result = $chain.Build($cert)
    foreach($element in $chain.ChainElements)
    {
        $element.Certificate | Format-List *
    }
}

# Make Instance call and print the response
$result = Query-InstanceEndpoint
$result | ConvertTo-JSON -Depth 99

# Make Attested call and parse the response
$result = Query-AttestedEndpoint
Parse-AttestedResponse $result
