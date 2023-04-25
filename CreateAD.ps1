[cmdletbinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$VmName,

    [Parameter(Mandatory=$false)]
    [ValidateSet("eastasia","southeastasia","centralus","eastus","eastus2","westus","northcentralus","southcentralus","northeurope","westeurope","japanwest","japaneast","brazilsouth","australiaeast","australiasoutheast","southindia","centralindia","westindia","canadacentral","canadaeast","uksouth","ukwest","westcentralus","westus2","koreacentral","koreasouth","francecentral","francesouth","australiacentral","australiacentral2")]
    [string]$Location="westus",

    [Parameter(Mandatory=$false)]
    [pscredential]$AdminCredential,

    [Parameter(Mandatory=$false)]
    [string]$Size = "Standard_B1s",

    [Parameter(Mandatory=$false)]
    [string]$Image = "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest", #"MicrosoftWindowsServer:WindowsServer:2022-datacenter-smalldisk-g2:latest",
    
    [Parameter(Mandatory=$false)]
    [pscredential]$VmTenantCredential,

    [Parameter(Mandatory=$false)]
    [switch]$StayLoggedIn,

    [Parameter(Mandatory=$false)]
    [switch]$Delete,

    [Parameter(Mandatory=$false)]
    [switch]$WithSSH
)

$script:Account = $null
$script:Subscription = $null
$script:ResourceGroup = $null
$script:SSHKeyPath = $null
$script:FQDN = $null
$script:RunningOS = ""

Function Write-Header([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

Function Write-Success([string]$Message) {
    Write-Host $Message -ForegroundColor Green
}

Function Test-Prerequisites {
    Write-Header "Checking prerequisites..."

    if (-Not ([bool](Get-Command -ErrorAction Ignore az))) {
        Write-Error "Please install azure cli`nhttps://learn.microsoft.com/en-us/cli/azure/"
        Exit 1
    }
    
    if (-Not (Get-Module -ListAvailable -Name "Microsoft.Graph")) {
        Write-Header "Installing Microsoft.Graph..."
        Install-Module Microsoft.Graph -Force
    }

    if ($IsLinux) {
        $script:RunningOS = "linux"
    } elseif ($IsMacOS) {
        $script:RunningOS = "osx"
    } else {
        $script:RunningOS = "win"
    }
}

Function Login {
    Write-Header "Logging into Azure..."
    if (-Not $VmTenantCredential) {
        Write-Header "Select the account to manage the VM."
        az login --allow-no-subscriptions --only-show-errors | Out-Null
    } else {
        az login -u $VmTenantCredential.UserName -p $VmTenantCredential.GetNetworkCredential().Password --only-show-errors | Out-Null
    }

    if ($SubscriptionId) {
        Write-Header "Setting subscription to $SubscriptionId"
        az account set --subscription $SubscriptionId | Out-Null
    }
    
    # Write-Header "Logging into graph..."
    # if (-Not $TenantCredential) {    
    #     Write-Header "Select the account to manage the profiles."
    #     $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$RunningOS.exe JWT"
    # } else {
    #     $script:JWT = Invoke-Expression "mstunnel-utils/mstunnel-$RunningOS.exe JWT $($TenantCredential.UserName) $($TenantCredential.GetNetworkCredential().Password)"
    # }
    
    # if (-Not $JWT) {
    #     Write-Error "Could not get JWT for account"
    #     Exit -1
    # }

    # Connect-MgGraph -AccessToken $script:JWT | Out-Null
    
    # # Switch to beta since most of our endpoints are there
    # Select-MgProfile -Name "beta"    
}

Function Logout {
    if (-Not $StayLoggedIn) {
        Write-Header "Logging out..."
        az logout
        $script:Account = Disconnect-MgGraph
    }
}

Function Initialize-Variables {

    if (-Not $Delete) {
        Write-Header "Provide credentials for the Windows administrator."
        if (-Not $AdminCredential) {
            $AdminCredential = Get-Credential
        }
    }

    $script:Account = (az account show | ConvertFrom-Json)
    $script:Subscription = $Account.id
    if ($Email -eq "") {
        Write-Header "Email not provided. Detecting email..."
        $script:Email = $Account.user.name
        Write-Host "Detected your email as '$Email'"
    }

    $script:ResourceGroup = "$VmName-group"
    $script:SSHKeyPath = "$HOME/.ssh/$VmName"

    $script:GraphContext = Get-MgContext
}

Function New-ResourceGroup {
    Write-Header "Checking for resource group '$resourceGroup'..."
    if ([bool](az group show --name $resourceGroup --subscription $Subscription 2> $null)) {
        Write-Error "Group '$resourceGroup' already exists"
        exit -1
    }
    
    Write-Header "Creating resource group '$resourceGroup'..."
    $groupData = az group create --subscription $subscription --location $location --name $resourceGroup --only-show-errors | ConvertFrom-Json
}

Function Remove-ResourceGroup {
    Write-Header "Checking for resource group '$resourceGroup'..."
    if ([bool](az group show --name $resourceGroup --subscription $Subscription 2> $null)) {
        Write-Header "Deleting resource group '$resourceGroup'..."
        az group delete --name $resourceGroup --yes --no-wait
    } else {
        Write-Host "Group '$resourceGroup' does not exist"
    }
}

Function New-VM {
    Write-Header "Creating VM '$VmName'..."
    $vmdata = az vm create --subscription $subscription --location $location --resource-group $resourceGroup --name $VmName --image $Image --size $Size --public-ip-address-dns-name $VmName --admin-username $AdminCredential.UserName --admin-password $AdminCredential.GetNetworkCredential().Password --only-show-errors | ConvertFrom-Json
    $script:FQDN = $vmdata.fqdns
    Write-Host "DNS is '$FQDN'"
}

Function New-NetworkRules {
    Write-Header "Creating network rules..."
    $nsg = "$($VmName)NSG"
    if ($WithSSH)
    {
        $publicKey = Get-Content "$SSHKeyPath.pub"
        Write-Host "Opening SSH port"
        az network nsg rule create --subscription $subscription --resource-group $resourceGroup --nsg-name $nsg -n SSHIN --priority 100 --source-address-prefixes '*' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow SSH" > $null
        Write-Host "Restarting VM to be able to add OpenSSH"
        az vm restart -g $resourceGroup -n $VmName
        Write-Host "Adding OpenSSH Server"
        az vm run-command invoke -g $resourceGroup -n $VmName --command-id RunPowerShellScript --scripts "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0"
        Write-Host "Adding public SSH key to server"
        az vm run-command invoke -g $resourceGroup -n $VmName --command-id RunPowerShellScript --scripts """$publicKey"" | Add-Content 'C:\ProgramData\ssh\administrators_authorized_keys';icacls.exe 'C:\ProgramData\ssh\administrators_authorized_keys' /inheritance:r /grant 'Administrators:F' /grant 'SYSTEM:F'"
        Write-Host "Setting OpenSSH server to start automatically"
        az vm run-command invoke -g $resourceGroup -n $VmName --command-id RunPowerShellScript --scripts "Get-Service -Name sshd | Set-Service -StartupType Automatic; Start-Service sshd"
        Write-Host "Restarting VM to complete OpenSSH installation"
        az vm restart -g $resourceGroup -n $VmName
    }
    
    az network nsg rule create --subscription $subscription --resource-group $resourceGroup --nsg-name $nsg -n HTTPIN --priority 101 --source-address-prefixes 'Internet' --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 443 --access Allow --protocol '*' --description "Allow HTTP" > $null
}

Function New-SSHKeys{
    if ($WithSSH) {
        Write-Header "Generating new RSA 4096 SSH Key"
        ssh-keygen -t rsa -b 4096 -f $SSHKeyPath -q -N ""
    }
}

Function Move-SSHKeys{
    if ($WithSSH) {
        Write-Header "Moving generated SSH keys..."
        Move-Item -Path ~/.ssh/id_rsa -Destination $sshKeyPath -Force
        Move-Item -Path ~/.ssh/id_rsa.pub -Destination ~/.ssh/$VmName.pub -Force    
    }
}

Function Remove-SSHKeys{
    if ($WithSSH) {
        Write-Header "Deleting SSH keys..."
        if (Test-Path $sshKeyPath) {
            Remove-Item -Path $sshKeyPath -Force
        } else {
            Write-Host "Key at path '$sshKeyPath' does not exist."
        }

        if (Test-Path ~/.ssh/$VmName.pub) {
            Remove-Item -Path ~/.ssh/$VmName.pub -Force 
        } else {
            Write-Host "Key at path '~/.ssh/$VmName.pub' does not exist."
        }
    }
}

Function Install-Roles{
    Write-Header "Installing Roles..."
    Write-Host "Installing AD-Domain-Services"
    az vm run-command invoke -g $resourceGroup -n $VmName --command-id RunPowerShellScript --scripts "Install-WindowsFeature -Name AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools"
}

Function Configure-Roles{
    Write-Header "Configuring Roles..."
    Write-Host "Configuring Active Directory"\
    $script = "Install-ADDSDomainController -DomainName $FQDN -InstallDns -Credential (New-Object System.Management.Automation.PSCredential -ArgumentList ""$($AdminCredential.UserName)"", (""$($AdminCredential.GetNetworkCredential().Password)"" | ConvertTo-SecureString -AsPlainText -Force))"
    Write-Host $script -ForegroundColor Magenta
    az vm run-command invoke -g $resourceGroup -n $VmName --command-id RunPowerShellScript --scripts $script
    
}

Function Create-Flow{
    Test-Prerequisites
    #Login
    Initialize-Variables
    New-SSHKeys
    New-ResourceGroup
    New-VM
    New-NetworkRules

    #Install-Roles
    #Configure-Roles
}

Function Delete-Flow {
    Test-Prerequisites
    #Login
    Initialize-Variables
    
    Remove-ResourceGroup
    Remove-SSHKeys
}


if ($Delete) {
    Delete-Flow
} else {
    Create-Flow
}