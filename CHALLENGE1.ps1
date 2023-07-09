<#
    A 3-tier environment is a common setup. Use a tool of your choosing/familiarity create these resources. 
    Please remember we will not be judged on the outcome but more focusing on the approach, style and reproducibility.
#>
# Fucntion to Connect Azure portal 
function Connect-KPMGAzure {
    [CmdletBinding()]
    param (
        [parameter(Mandatory)]
        [string]
        $ApplicationId,
        [parameter(Mandatory)]
        [SecureString]
        $SecuredPassword
    )
    
    begin {
        $isOpration = $true
        $conect = Get-AzContext
        if ($null -eq $conect) {
            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ApplicationId, $SecuredPassword
        }
        else {
            Write-Error $_
            Exit
        }
    }
    
    process {
        try {
            $Context = Connect-AzAccount -ServicePrincipal -TenantId $TenantId -Credential $Credential, $SecuredPassword            
        }
        catch {
            $isOpration = $false 
            Write-Error $_
        }
    }
    
    end {
        if ($isOpration) {
            Write-Verbose "$($Context.SubscriptionName) connect to Azure"
        }
        else {
            Write-Verbose 'Failed to connect Azure'
        }
    }
}

# Function to provision the Resources 
function New-KPMGResourceGroup {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'FriendlyName',
        Justification = 'False positive as rule does not scan child scopes')]		
    param(
        [parameter(Mandatory)]
        [string]$Name,
        [string]$FriendlyName,
        [parameter(Mandatory)]
        [string]$Location
    )

    Write-Verbose 'Ensure resource group exists'
    $resourceGroup = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
    if (!$resourceGroup) {
        Write-Verbose "Creating resource group '$Name' in location '$Location'"
        New-AzResourceGroup -Name $Name -Location $Location
    }
    else {
        Write-Verbose "Resource group already exist. Using existing resource group '$Name'"
    }
}
# function to create 1st tier Resources 
function New-KPMGVirtualNetworkGatewayName {
    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [string] $VnetName,
        [string] $resourceGroup,
        [PSCustomObject]
        $providerConfig
        
    )
    
    begin {
        $params.VirtualNetworkGatewayName = 'KPMG_VirtualNetworkGatewayName'
        $params.PublicIpAddressName = $params.VirtualNetworkGatewayName + "-pip"
        
        $vnetId = (Get-AzVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vNetName).Id
        
        #the purpose for the resources. Currently in configuration table
        $ProviderConfigurations.tagsData.Purpose = $params.Purpose
        
        $templateParameters = @{
            "VirtualNetworkGatewayName" = $params.VirtualNetworkGatewayName
            "vNetId"                    = $vnetId
            "location"                  = "EASE US2"
        }					
            
        if (-not [string]::IsNullOrWhiteSpace($deploymentInfo.Details."$($NetworkPrefix)Networking".vNetResourceGroup)) {
            $resourceGroupName = $deploymentInfo.Details."$($NetworkPrefix)Networking".vNetResourceGroup
        }
        else {
            $resourceGroupName = New-MCResourceGroupNameV2 -EnvironmentCode $EnvironmentCode -ApplicationCode $ApplicationCodes.EnterpriseLendingCenter -ClientName $DepartmentCode -ResourceGroupFriendlyName $ResourceGroupFriendlyName -NoSequenceNumber
        }

        $providerConfig.TemplateParameters = $templateParameters
        $providerConfig.ResourceGroupName = $resourceGroupName
        $providerConfig.TemplateFilePath = $ProviderConfigurations.TemplateFilePath
        $providerConfig.DeploymentName = "$EnvironmentCode$ApplicationCode$($DepartmentCode)$($params.role[0])"
        $providerConfig.ResourceRole = $params.role[0]
    }
    
    process {
        $result = New-AzResourceGroupDeployment -ResourceGroupName $ProvisionConfig.ResourceGroupName -Name $ProvisionConfig.DeploymentName -TemplateFile $ProvisionConfig.TemplateFilePath -TemplateParameterObject $ProvisionConfig.TemplateParameters -ErrorAction Stop
        end {
            if ($isOpration) {
                Write-Verbose "$($providerConfig.TemplateParameters.VirtualNetworkGatewayName) resource created Succssfully"
                return $result.Outputs
            }
            else {
                Write-Verbose "Failed to create $($providerConfig.TemplateParameters.VirtualNetworkGatewayName)"
            }
        }
    }
}
# function to create 2nd tier Resources 
function New-KPMGVirtualMachine {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]
        $providerConfig
    )
    
    begin {
        $isOpration = $true
        $templateParameters = @{
            "location"           = "East Us2"
            "adminUsername"      = 'AdminName'
            "adminPassword"      = "adminPassword" #| ConvertFrom-MCSecureStringToPlainText
            "domainAdmin"        = "DomainName"
            "domainPassword"     = "DomainPassword"
            "virtualMachineName" = "KPMGVM1"
            "vnetId"             = "vnetId_sdgdh"
            "subnetName"         = "subnetName_Name"
        }
        $providerConfig.TemplateFilePath = ".\\ResourceGroups\\ARMTemplates\\VirtualMachineTemplate.json"
        $providerConfig.ResourceGroupName = $ResourceGroupName
        $providerConfig.DeploymentName = "KPMG$($Resource)"
        $providerConfig.TemplateParameters = $TemplateParameters
    }
    
    process {
        try {
            #if exist don't update the resourcegroup to prevent tags from changing
            $rgvalue = Get-AzResourceGroup -Name $ProvisionConfig.ResourceGroupName -ErrorAction SilentlyContinue
            if (-not $rgvalue) {
                $resourceGroupResult = New-KPMGResourceGroup -Name $ProvisionConfig.ResourceGroupName -Location $ProvisionConfig.TemplateParameters.location
                Write-Output $resourceGroupResult
            }

            $result = New-AzResourceGroupDeployment -ResourceGroupName $ProvisionConfig.ResourceGroupName -Name $ProvisionConfig.DeploymentName -TemplateFile $ProvisionConfig.TemplateFilePath -TemplateParameterObject $ProvisionConfig.TemplateParameters -ErrorAction Stop
        }
        catch {
            Write-Error $_
        }
    }
    end {
        if ($isOpration) {
            Write-Verbose "$($providerConfig.TemplateParameters.virtualMachineName) resource created Succssfully"
            return $result.Outputs

        }
        else {
            Write-Verbose "Failed to create $($providerConfig.TemplateParameters.virtualMachineName)"
        }
    }
}
# function to create 3rd tier Resources 
function New-KPMGKPMGServerName {
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory)]
        [PSCustomObject]
        $ProvisionConfig
    )
    
    begin {
        $isOpration = $true
        $templateParameters = @{			
            "administratorLogin"         = $ProvisionConfig.administratorLogin
            "administratorLoginPassword" = $ProvisionConfig.administratorLoginPassword
            "serverName"                 = 'KPMGServerName'
            "databaseNames"              = "DatabaseNames"
        }
        $resourceGroupName = New-KPMGResourceGroup -Name $ProvisionConfig.ResourceGroupName -Location $ProvisionConfig.TemplateParameters.location

        $ProvisionConfig.TemplateParameters = $templateParameters
        $ProvisionConfig.ResourceGroupName = $resourceGroupName
        $ProvisionConfig.TemplateFilePath = $ProviderConfigurations.TemplateFilePath
        $ProvisionConfig.DeploymentName = $params.ServerName
    }
    
    process {
        try {
            $result = New-AzResourceGroupDeployment -ResourceGroupName $ProvisionConfig.ResourceGroupName -Name $ProvisionConfig.DeploymentName -TemplateFile $ProvisionConfig.TemplateFilePath -TemplateParameterObject $ProvisionConfig.TemplateParameters -ErrorAction Stop            
        }
        catch {
            $isOpration = $false
        }

    }
    end {
        if ($isOpration) {
            Write-Verbose "$($ProvisionConfig.TemplateParameters.KPMGServerName) resource created Succssfully"
            return $result.Outputs

        }
        else {
            Write-Verbose "Failed to create $($ProvisionConfig.TemplateParameters.KPMGServerName)"
        }
    }
}
# Function to invoke the application code

# Start Here
# Paramater section 
$administratorLoginPassword = "<secureSting>"
$ResourceGroupName = "KPMG-Rg"
$providerConfig = @{
    "TemplateParameters"         = ""
    "ResourceGroupName"          = ""
    "TemplateFilePath"           = ""
    "DeploymentName"             = ""
    "AdminName"                  = "GaneshVahinde"
    "administratorLogin"         = "KPMGADMIN"
    "administratorLoginPassword" = $administratorLoginPassword
}

Connect-KPMGAzure -ApplicationId '' -SecuredPassword ''
New-KPMGVirtualNetworkGatewayName -VNetName 'KPMGVNetName' -providerConfig $providerConfig 
New-KPMGVirtualMachine -VNetName 'KPMGVNetName' -resourceGroup 'KPMG-Rg' -providerConfig $providerConfig 
New-KPMGKPMGServerName -providerConfig $providerConfig 


