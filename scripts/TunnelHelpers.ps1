Enum Platform {
    all
    ios
    android
}

Enum RunningOs {
    win
    osx
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
    [string] $Image = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest"
    [string] $ProxyImage = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest"
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
    [string] $ADApplication = "Generated MAM Tunnel"
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
    [object[]] $SupportedEndpoints = @()
    [pscredential[]] $AuthenticatedProxyCredentials = @()
    [Object] $ServerConfiguration
    [Object] $TunnelSite
    [Int32] $ListenPort = 443
    [string] $Subnet = "169.254.0.0/16"
    [string[]] $IncludeRoutes = @()
    [string[]] $ExcludeRoutes = @()
    [bool] $BootDiagnostics = $false
    [string] $TunnelTestEnvCommit
    [bool] $WithIPv6 = $false
    [string] $TunnelIPv6Name
    [string] $TunnelIPv6Address
    [string] $TunnelServiceIPv6Name
    [string] $TunnelServiceIPv6Address
}

Class Constants {
    static [string] $CertFileName = "cacert.pem.tmp"
    static [string[]] $DefaultBypassUrls = @("www.google.com", "excluded", "excluded.$($Context.TunnelFQDN)")
    static [string] $ServerVMImage = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest"
}

Function Set-Endpoints() {
    $script:Context.SupportedEndpoints = @(
        @{label= "Require Cert"; url= "https://cert.$($Context.TunnelFQDN)"},
        @{label= "Optional Cert"; url= "https://optionalcert.$($Context.TunnelFQDN)"},
        @{label= "Fetch Cert"; url= "https://$($Context.TunnelFQDN)/user.pfx"},
        @{label= "Webapp"; url= "https://webapp.$($Context.TunnelFQDN)"},
        @{label= "Fuzz"; url= "https://fuzz.$($Context.TunnelFQDN)"},
        @{label= "Excluded By PAC"; url= "https://excluded.$($Context.TunnelFQDN)"},
        @{label= "Webapp Short"; url= "https://webapp"},
        @{label= "Fuzz Short"; url= "https://fuzz"},
        @{label= "Excluded Short"; url= "https://excluded"},
        @{label= "Untrusted"; url= "https://untrusted.$($Context.TunnelFQDN)"},
        @{label= "PAC Included IP API"; url= "https://webapp.$($Context.TunnelFQDN)/api/IPAddress"},
        @{label= "PAC Excluded IP API"; url= "https://excluded.$($Context.TunnelFQDN)/api/IPAddress"},
        @{label= "Context"; url= "https://$($Context.TunnelFQDN)/context.json"},
        @{label= "PAC File"; url= "https://$($Context.TunnelFQDN)/tunnel.pac"})
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

# Give me an IPv6 address, like 2a01:111:f100:3000::a83e:1938/256 and a prefix length, like 64, and I return a valid prefix, like 2a01:111:f100:3000::/64.
# This implementation uses simple string manipulation and won't handle all IP addresses, such as those where :: in the prefix is short for :0000:0000:.
# prefixLength must be a multiple of 16.
# You could probably make it more robust by using the .Net IPAddress type.
Function Get-IPv6Prefix {
    param(
        [string] $address,
        [Int32] $prefixLength
    )

    if ($address.Contains("/")) {
        # Trim any trailing prefix length, like "/126".
        $address = $address.Substring(0, $address.IndexOf("/"))
    }

    $address = $address.Replace("::", ":0:")    # Will break for addresses with multiple adjacent 0 quartets. This is unlikely for Azure addresses. 

    $quartets = $address.Split(":")
    $numQuartets = ($prefixLength / 16)     # Sixteen bits per quartet.

    $prefix = $quartets[0..($numQuartets - 1)] -join ":"
    $prefix += "::/" + $prefixLength

    return $prefix
}
