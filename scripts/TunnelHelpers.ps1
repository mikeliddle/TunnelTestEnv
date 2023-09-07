Enum Platform {
    all
    ios
    android
}

Enum RunningOs {
    win
    mac
    linux
}

Class TunnelContext {
    [string] $VmName
    [string] $ProxyVmName
    [string] $ResourceGroup
    [string] $Location = "westus"
    [Platform] $Platform = "all"
    [string[]] $BundleIds = @()
    [string] $GroupName
    [string] $Environment = "PE"
    [string] $Email
    [string] $Username = "azureuser"
    [string] $Size = "Standard_B2s"
    [string] $ProxySize = "Standard_B2s"
    [string] $Image = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest"
    [string] $ProxyImage = "Canonical:0001-com-ubuntu-server-focal:20_04-lts:latest"
    [bool] $NoProxy = $false
    [bool] $WithSSHOpen = $false
    [bool] $NoPACUrl = $false
    [bool] $NoPki = $false
    [bool] $UseInspection = $false
    [bool] $UseAllowList = $false
    [string] $PACUrl
    [string] $ProxyHostname
    [string] $ProxyPort
    [RunningOs] $RunningOS = "win"
    [string] $SubscriptionId
    [string] $TenantId
    [string] $ADApplication
    [Object] $Subscription
    [Object] $Account
    [string] $SSHKeyPath = "$HOME/.ssh/$VmName"
    [Object] $GraphContext
    [Object] $Group
    [string] $ServiceFQDN
    [string] $TunnelFQDN
    [string] $VnetName
    [string] $SubnetName
    [string] $ProxyIP
    [pscredential[]] $AuthenticatedProxyCredentials = @()
    [Object] $ServerConfiguration
    [Object] $TunnelSite
    [Int32] $ListenPort = 443
    [string] $Subnet = "169.254.0.0/16"
    [string[]] $IncludeRoutes = @()
    [string[]] $ExcludeRoutes = @()
}

Class Constants {
    $CertFileName = "cacert.pem.tmp"
    $DefaultBypassUrls = @("www.google.com", "excluded", "excluded.$($Context.TunnelFQDN)")
}

Function Write-Header([string]$Message) {
    Write-Host $Message -ForegroundColor Cyan
}

Function Write-Success([string]$Message) {
    Write-Host $Message -ForegroundColor Green
}

Function Write-Warning([string]$Message) {
    Write-Host $Message -ForegroundColor Yellow
}
Function New-SSHKeys {
    Write-Header "Generating new RSA 4096 SSH Key"
    
    ssh-keygen -t rsa -b 4096 -f $Context.SSHKeyPath -q -N ""
}

Function Move-SSHKeys {
    Write-Header "Moving generated SSH keys..."
    Move-Item -Path ~/.ssh/id_rsa -Destination $Context.SSHKeyPath -Force
    Move-Item -Path ~/.ssh/id_rsa.pub -Destination "$($Context.SSHKeyPath).pub" -Force    
}

Function Remove-SSHKeys {
    Write-Header "Deleting SSH keys..."

    if (Test-Path $Context.SSHKeyPath) {
        Remove-Item -Path $($Context.SSHKeyPath) -Force
    }
    else {
        Write-Host "Key at path '$($Context.SSHKeyPath)' does not exist."
    }

    if (Test-Path "$($Context.SSHKeyPath).pub") {
        Remove-Item -Path "$($Context.SSHKeyPath).pub" -Force 
    }
    else {
        Write-Host "Key at path '$($Context.SSHKeyPath).pub' does not exist."
    }

    Write-Header "Deleting SSH keys from known hosts..."
    ssh-keygen -R $Context.TunnelFQDN
    ssh-keygen -R $Context.ServiceFQDN
}

Function Remove-TempFiles {
    Remove-ItemIfExists -Path proxy/*.tmp
    Remove-ItemIfExists -Path nginx_data/tunnel.pac.tmp
    Remove-ItemIfExists -Path nginx.conf.d/nginx.conf.tmp
    Remove-ItemIfExists -Path cacert.pem.tmp
    Remove-ItemIfExists -Path scripts/*.tmp
    Remove-ItemIfExists -Path agent.p12
    Remove-ItemIfExists -Path agent-info.json
}

Function Remove-ItemIfExists {
    param(
        [string] $Path
    )
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force
    }
}

Function New-RandomPassword {
    # Define the character sets to use for the password
    $lowercaseLetters = "abcdefghijklmnopqrstuvwxyz"
    $uppercaseLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $numbers = "0123456789"
    $specialCharacters = "!@#$%&*()_+-=[]{};:,./<>?"

    # Combine the character sets into a single string
    $validCharacters = $lowercaseLetters + $uppercaseLetters + $numbers + $specialCharacters

    # Define the length of the password
    $passwordLength = 16

    # Generate the password
    $password = ""
    for ($i = 0; $i -lt $passwordLength; $i++) {
        # Get a random index into the valid characters string
        $randomIndex = Get-Random -Minimum 0 -Maximum $validCharacters.Length

        # Add the character at the random index to the password
        $password += $validCharacters[$randomIndex]
    }

    Write-Success "Generated password: $password"

    # Output the password
    return $password
}