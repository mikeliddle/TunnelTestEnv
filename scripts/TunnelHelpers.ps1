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
    param(
        [string] $SSHKeyPath
    )
    Write-Header "Generating new RSA 4096 SSH Key"
    
    ssh-keygen -t rsa -b 4096 -f $SSHKeyPath -q -N ""
}

Function Move-SSHKeys {
    param(
        [string] $SSHKeyPath
    )
    Write-Header "Moving generated SSH keys..."
    Move-Item -Path ~/.ssh/id_rsa -Destination $SSHKeyPath -Force
    Move-Item -Path ~/.ssh/id_rsa.pub -Destination $SSHKeyPath.pub -Force    
}

Function Remove-SSHKeys {
    param(
        [string] $SSHKeyPath,
        [string] $TunnelFQDN,
        [string] $ServiceFQDN
    )

    Write-Header "Deleting SSH keys..."

    if (Test-Path $SSHKeyPath) {
        Remove-Item -Path $SSHKeyPath -Force
    }
    else {
        Write-Host "Key at path '$SSHKeyPath' does not exist."
    }

    if (Test-Path "$SSHKeyPath.pub") {
        Remove-Item -Path "$SSHKeyPath.pub" -Force 
    }
    else {
        Write-Host "Key at path '$SSHKeyPath.pub' does not exist."
    }

    Write-Header "Deleting SSH keys from known hosts..."
    ssh-keygen -R $TunnelFQDN
    ssh-keygen -R $ServiceFQDN
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