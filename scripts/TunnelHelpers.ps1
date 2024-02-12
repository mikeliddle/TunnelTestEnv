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
    [string] $ServiceFQDNIpv6
    [string] $TunnelFQDNIpv6
    [string] $VnetName
    [string] $SubnetName
    [string] $NSGName
    [string] $ProxyIP
    [string] $ProxyIPv6
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
    [Object] $TunnelGatewayIPv6Address
    [Object] $TunnelServiceIPv6Address
    [string] $TunnelNicName
    [string] $ServiceNicName
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
        @{label= "Excluded By PAC"; url= "https://excluded.$($Context.TunnelFQDN)"},
        @{label= "Webapp Short"; url= "https://webapp"},
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

# Give me an IPv6 address, like 2a01:111:f100:3000::a83e:1938 and a prefix length, like 64, and I return a valid prefix string, like "2a01:111:f100:3000::/64".
# This function isn't currently used, but it will be needed when we stop hardcoding the IPv6 address.
function Get-IPv6Prefix {
    param (
        [string]$IPv6Address,
        [int]$NumPrefixBits
    )

    $IPv6AddressBytes = [System.Net.IPAddress]::Parse($IPv6Address).GetAddressBytes()
    $IPv6AddressBits = [System.BitConverter]::ToString($IPv6AddressBytes).Replace('-','')
    $leftBits = $IPv6AddressBits.Substring(0, 16)
    $leftBits = [System.Convert]::ToUInt64($leftBits, 16)
    $rightBits = $IPv6AddressBits.Substring(16, 16)
    $rightBits = [System.Convert]::ToUInt32($rightBits, 16)

    # Create a bitmask for the left bits.
    $mask = ""
    $numLeftOneBits = [Math]::Min(64, $NumPrefixBits)
    for ($i = 0; $i -lt $numLeftOneBits; $i++) {
        $mask = $mask + "1"
    }
    $numLeftZeroBits = [Math]::Min(64 - $numLeftOneBits, 64)
    for ($i = 0; $i -lt $numLeftZeroBits; $i++) {
        $mask = $mask + "0"
    }   
    [UInt64]$leftBitmask = [System.Convert]::ToUInt64($mask, 2)
    $maskedLeftAddress = $leftBits -band $leftBitmask

    # Create a bitmask for the right bits.
    $mask = ""
    $numRightOneBits = [Math]::Max(0, $NumPrefixBits - 64)
    for ($i = 0; $i -lt $numRightOneBits; $i++) {
        $mask = $mask + "1"
    }
    $numRightZeroBits = [Math]::Min(64 - $numRightOneBits, 64)
    for ($i = 0; $i -lt $numRightZeroBits; $i++) {
        $mask = $mask + "0"
    }   
    [UInt64]$rightBitmask = [System.Convert]::ToUInt64($mask, 2)
    $maskedRightAddress = $rightBits -band $rightBitmask

    # Convert the two 64-bit numbers into a byte array with the bytes in the right order.
    $prefixBytes =  New-Object Byte[] 16
    $leftBytes = [System.BitConverter]::GetBytes($maskedLeftAddress) 
    for ($i = 0; $i -lt 8; $i++) {
        $prefixBytes[$i] = $leftBytes[8 - $i - 1]
    }
    $rightBytes = [System.BitConverter]::GetBytes($maskedRightAddress) 
    for ($i = 0; $i -lt 8; $i++) {
        $prefixBytes[$i + 8] = $rightBytes[8 -$i - 1]
    }

    # Create an IPv6 string address from #prefixBytes.
    $hexString = [System.BitConverter]::ToString($prefixBytes) -replace "-", ""
    $hexString = "{0}:{1}:{2}:{3}:{4}:{5}:{6}:{7}" -f $hexString.Substring(0, 4), $hexString.Substring(4, 4), $hexString.Substring(8, 4), $hexString.Substring(12, 4), $hexString.Substring(16, 4), $hexString.Substring(20, 4), $hexString.Substring(24, 4), $hexString.Substring(28, 4)
    $ip = [System.Net.IPAddress]::Parse($hexString)

    $CIDRAddress = $ip.IPAddressToString
    return $CIDRAddress.ToString() + '/' + $NumPrefixBits
}

# Give me an IPv4 address, like 20.253.142.17 and a prefix length, like 16, and I return a valid prefix string, like "20.253.0.0/16".
# This function isn't currently used, but it may be needed if we ever stop hardcoding the IPv4 private address.
function Get-IPv4Prefix {
    param (
        [string]$IPAddress,
        [int]$NumPrefixBits
    )
    $IP = [System.Net.IPAddress]::Parse($IPAddress)
    [UInt32]$address = $Ip.Address
    $mask = ""
    for ($i = 32; $i -gt $NumPrefixBits; $i--) {
        $mask = $mask + "0"
    }
    for ($i = 0; $i -lt $NumPrefixBits; $i++) {
        $mask = $mask + "1"
    }   
    [UInt32]$bitmask = [System.Convert]::ToUInt32($mask, 2)
    [UInt32]$maskedAddress = $address -band $bitmask

    $IPPrefix = [System.Net.IPAddress]::new($maskedAddress)

    #$CIDRNotation = ([IPAddress]::Parse(([convert]::ToUInt32($binaryString, 2)).ToString())).ToString()
    $CIDRNotation = $IPPrefix.ToString()
    $CIDRNotation = $CIDRNotation + "/" + $NumPrefixBits

    return $CIDRNotation
}
