$ImdsServer = "http://169.254.169.254"
$InstanceEndpoint = $ImdsServer + "/metadata/instance"
$AttestedEndpoint = $ImdsServer + "/metadata/attested/document"
$NonceValue = "123456"
$MetadataDnsSuffix = ".metadata.azure.com"
$SubjectAlternativeNameOid = "2.5.29.17"

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
    $uri = $InstanceEndpoint + "?api-version=2023-07-01"
    $result = Invoke-RestMethod -Method GET -NoProxy -Uri $uri -Headers @{"Metadata"="True"}
    return $result
}

function Query-AttestedEndpoint
{
    $uri = $AttestedEndpoint + "?api-version=2023-07-01&nonce=" + $NonceValue
    $result = Invoke-RestMethod -Method GET -NoProxy -Uri $uri -Headers @{"Metadata"="True"}
    return $result
}

function Parse-AttestedResponse
{
    param
    (
        [PSObject]$response
    )
    if ($null -eq $response -or $response.encoding -ine "pkcs7")
    {
        throw "Attested document is not PKCS#7 encoded."
    }

    Validate-AttestedData $response.signature
}

function Validate-AttestedData
{
    param
    (
        [string]$signature
    )
    $decoded = [System.Convert]::FromBase64String($signature)
    $signedCms = New-Object -TypeName System.Security.Cryptography.Pkcs.SignedCms
    $signedCms.Decode($decoded)
    if ($signedCms.SignerInfos.Count -ne 1)
    {
        throw "Expected exactly one attested-document signer."
    }

    $signerInfo = $signedCms.SignerInfos[0]
    $signerInfo.CheckSignature($true)
    $signerCertificate = $signerInfo.Certificate
    if ($null -eq $signerCertificate)
    {
        throw "The attested-document signer certificate is missing."
    }

    $hasSubjectAlternativeName = $null -ne ($signerCertificate.Extensions | Where-Object {
        $_.Oid.Value -eq $SubjectAlternativeNameOid
    } | Select-Object -First 1)
    $dnsName = $signerCertificate.GetNameInfo(
        [System.Security.Cryptography.X509Certificates.X509NameType]::DnsName,
        $false)
    if (-not $hasSubjectAlternativeName -or
        -not ($dnsName -ieq $MetadataDnsSuffix.Substring(1) -or
              $dnsName.EndsWith($MetadataDnsSuffix, [System.StringComparison]::OrdinalIgnoreCase)))
    {
        throw "Signer certificate is not valid for Azure IMDS."
    }

    $chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
    try
    {
        $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online
        $chain.ChainPolicy.RevocationFlag = [System.Security.Cryptography.X509Certificates.X509RevocationFlag]::ExcludeRoot
        $chain.ChainPolicy.VerificationFlags = [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
        $chain.ChainPolicy.ExtraStore.AddRange($signedCms.Certificates)
        if (-not $chain.Build($signerCertificate))
        {
            throw "Attested-document signer certificate chain is not trusted."
        }

        foreach ($element in $chain.ChainElements)
        {
            $element.Certificate | Format-List *
        }
    }
    finally
    {
        $chain.Dispose()
    }

    $content = [System.Text.Encoding]::UTF8.GetString($signedCms.ContentInfo.Content)
    $json = $content | ConvertFrom-Json
    if ($null -eq $json -or $json.nonce -cne $NonceValue)
    {
        throw "Attested-document nonce does not match the request."
    }

    Write-Host "Attested data: " $content
    Write-Host "Nonce values match"
}

# Make Instance call and print the response
$result = Query-InstanceEndpoint
$result | ConvertTo-JSON -Depth 99

# Make Attested call and parse the response
$result = Query-AttestedEndpoint
Parse-AttestedResponse $result
