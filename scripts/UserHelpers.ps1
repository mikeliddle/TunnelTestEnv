. ./TunnelHelpers.ps1

Function New-TunnelUser {
    param(
        [pscredential] $Credentials = $nil,
        [string] $DisplayName = $nil,
        [string] $Location = "US",
        [string] $LicenseTemplateUsername = "admin"
    )
    Write-Header "Creating new user..."
    $Domain = (Get-MgDomain).Id
    
    if (-Not $Credentials) {
        # Generate a username based on existing usernames and the current environment user
        $i = 0
        do{
            $UserName = "$($env:USER).gen$i"
            $i++
        } while (Get-MgUser -Filter "UserPrincipalName eq '$UserName@$Domain'");
        $SecStringPassword = ConvertTo-SecureString "JustLetMeIn" -AsPlainText -Force
        
        $Credentials = New-Object System.Management.Automation.PSCredential ($UserName, $secStringPassword)
    } else {
        $UserName = $Credentials.UserName
    }

    Write-Host "Creating user '$UserName'..."

    if (-Not $DisplayName) {
        $DisplayName = $UserName
    }
    
    $Upn = "$UserName@$Domain"
    $PasswordProfile = @{
        Password = $Credentials.GetNetworkCredential().Password
        ForceChangePasswordNextSignIn = $false
    }
    $PasswordPolicies = "DisablePasswordExpiration,DisableStrongPassword"

    $user = New-MGUser -DisplayName $DisplayName -PasswordProfile $PasswordProfile -PasswordPolicies $PasswordPolicies -AccountEnabled -MailNickname $UserName -UserPrincipalName $Upn -UsageLocation $Location

    if (-Not $user) {
        return
    }

    try {
        Write-Host "Licensing user '$UserName'..."
        # Clone the licenses of the license template user
        $licenseTemplateUser = Get-MgUser -Filter "UserPrincipalName eq '$LicenseTemplateUsername@$domain'"
        $templateLicenseDetails = Get-MgUserLicenseDetail -UserId $licenseTemplateUser.Id
        $Skus = $templateLicenseDetails | Foreach-Object{ @{SkuId= $_.SkuId} }
        
        $licenses = Set-MgUserLicense -UserId $user.Id -AddLicenses $skus -RemoveLicenses @()
    }
    catch {
        Write-Error "Could not license new user. Removing user."
        Remove-TunnelUser -UserName $UserName
        throw
    }

    $group = New-TunnelGroup -User $user
}

Function New-TunnelGroup {
    param(
        [Parameter(Mandatory=$true, ParameterSetName="GroupName")]
        [string] $GroupName,
        [Parameter(Mandatory=$true, ParameterSetName="User")]
        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphUser] $User
    )
    try {
        if ($GroupName -or $GroupName.Length -eq 0) {
            $GroupName = $User.MailNickname
        }
        Write-Header "Creating group '$GroupName'..."

        $group = New-MgGroup -DisplayName $GroupName -MailEnabled:$false -MailNickname $GroupName -SecurityEnabled
        
        if (-Not $group -and $User) {
            Write-Error "Could not create new group. Removing user '$($User.MailNickname)'."
            Remove-TunnelUser -UserName $User.MailNickname
            return
        }

        if ($User) {
            $member = New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $User.Id
        }
    }
    catch {
        if ($User) {
            Write-Error "Could not create new group. Removing user."
            Remove-TunnelUser -UserName $UserName
        }
        throw
    }
}

Function Remove-TunnelUser {
    param(
        [string] $UserName
    )
    $Domain = (Get-MgDomain).Id
    $Upn = "$UserName@$Domain"
    Write-Header "Removing user '$UserName'..."

    $User = Get-MgUser -Filter "UserPrincipalName eq '$Upn'"

    if (-Not $User) {
        Write-Information "User '$Upn' does not exist"
    } else {
        Remove-MgUser -UserId $User.Id
    }

    $Group = Get-MgGroup -Filter "DisplayName eq '$UserName'"
    if (-Not $Group) {
        Write-Information "Group '$Username' does not exist"
    } else {
        Remove-MgGroup -GroupId $Group.Id
    }
}

Function Remove-ConventionBasedUsers {
    $conventionUserName = $($env:USER)
    Write-Header "Removing all users for '$conventionUserName'..."
    $Domain = (Get-MgDomain).Id
    $Upn = "$UserName@$Domain"

    $Users = Get-MgUser -Filter "startsWith(UserPrincipalName, '$conventionUserName.gen')"
    foreach ($User in $users) {
        Remove-TunnelUser -UserName $User.DisplayName
    }
}

# Required scopes
#Connect-MgGraph -Scopes @( "User.ReadWrite.All", "Organization.Read.All" )