# Introducing User Data

When creating a new VM, you can specify a set of data to be used during or after the VM provision, and retrieve it through IMDS. 

To set up user data, utilize the quickstart template here. 
 
**Note:** This feature is released with IMDS version 2021-01-01 and depends upon an update to the Azure platform, which is currently being rolled out and may not yet be available in every region.

**Note:** Security notice: IMDS is open to all applications on the VM, sensitive data should not be placed in the user data.

To retirve the user data, utilize the sample code below:

### Windows
```powershell
Invoke-RestMethod -Headers @{"Metadata"="true"} -Method GET -Proxy $Null -Uri "http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text" | base64 --decode
```

### Linux

```bash
curl -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance/compute/userData?api-version=2021-01-01&format=text" | base64 --decode
```

## How about custom data?

User data offers the similar functionality to custom data, allowing you to pass your own metadata to the VM instance. The difference is, user data is retrieved through IMDS, and is persistent throughout the lifetime of the VM instance. Existing custom data feature will continue to work as described in [this article](https://docs.microsoft.com/azure/virtual-machines/custom-data). However you can only get custom data through local system folder, not through IMDS.

## Deploy a Virtual Machine with UserData

This template allows you to create a Virtual Machine with User Data. This template also deploys a Virtual Network, Public IP addresses, and a Network Interface.
