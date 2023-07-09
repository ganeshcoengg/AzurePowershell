<#
    We need to write code that will query the meta data of an instance within AWS/Azure and provide a json formatted output. 
    The choice of language and implementation is up to you.
#>
function Get-InstanceEndpoint
{
    param(
        [string]
        $InstanceEndpoint
    )

    $uri = $InstanceEndpoint + "?api-version=2021-02-01"
    $result = Invoke-RestMethod -Method GET -NoProxy -Uri $uri -Headers @{"Metadata"="True"}
    return $result
}

$ImdsServer = "http://10.10.10.15"
$InstanceEndpoint = $ImdsServer + "/metadata/instance"

Get-InstanceEndpoint | ConvertTo-JSON -Depth 90