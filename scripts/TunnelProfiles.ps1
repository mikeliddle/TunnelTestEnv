#region Graph Functions
Function Login-Graph {
    param(
        [PSCredential] $TenantCredential = $null
    )

    $GraphContext = Get-MgContext

    if ($GraphContext) {
        Write-Warning "Already signed into graph as $($GraphContext.Account)"
        Write-Warning "If you don't want to use this account, please logout, then run this script again."
    }
    else {
        Write-Header "Logging into graph..."
        if (-Not $TenantCredential) {
            $JWT = Invoke-Expression "mstunnel-utils/mstunnel-$($Context.RunningOS).exe JWT"
        }
        else {
            $JWT = Invoke-Expression "mstunnel-utils/mstunnel-$($Context.RunningOS).exe JWT '$($TenantCredential.Username)' '$($TenantCredential.GetNetworkCredential().Password)'"
        }
        
        if (-Not $JWT) {
            Write-Error "Could not get JWT for account"
            Exit -1
        }

        Connect-MgGraph -AccessToken $JWT | Out-Null
        
        # Switch to beta since most of our endpoints are there
        Select-MgProfile -Name "beta"
    }
}
#endregion Graph Functions

#region Tunnel Server Profiles
Function New-TunnelConfiguration {
    Write-Header "Creating Server Configuration..."
    $script:Context.ServerConfiguration = Get-MgDeviceManagementMicrosoftTunnelConfiguration -Filter "displayName eq '$($Context.VmName)'" -Limit 1
    if ($Context.ServerConfiguration) {
        Write-Host "Already found Server Configuration named '$($Context.VmName)'"
    }
    else {
        $script:Context.ServerConfiguration = New-MgDeviceManagementMicrosoftTunnelConfiguration -DisplayName $Context.VmName -ListenPort $Context.ListenPort -DnsServers $Context.ProxyIP -Network $Context.Subnet -AdvancedSettings @() -DefaultDomainSuffix $Context.TunnelFQDN -RoleScopeTagIds @("0") -RouteExcludes $Context.ExcludeRoutes -RouteIncludes $Context.IncludeRoutes -SplitDns @()
    }
}

Function Remove-TunnelConfiguration {
    Write-Header "Deleting Server Configuration..."
    $Context.ServerConfiguration = Get-MgDeviceManagementMicrosoftTunnelConfiguration -Filter "displayName eq '$($Context.VmName)'" -Limit 1

    if ($Context.ServerConfiguration) {
        Remove-MgDeviceManagementMicrosoftTunnelConfiguration -MicrosoftTunnelConfigurationId $Context.ServerConfiguration.Id
    }
    else {
        Write-Host "Server Configuration '$($Context.VmName)' does not exist."
    }
}

Function New-TunnelSite {
    Write-Header "Creating Site..."
    $Context.TunnelSite = Get-MgDeviceManagementMicrosoftTunnelSite -Filter "displayName eq '$($Context.VmName)'" -Limit 1

    if ($Context.TunnelSite) {
        Write-Host "Already found Site named '$($Context.VmName)'"
    }
    else {
        $Context.TunnelSite = New-MgDeviceManagementMicrosoftTunnelSite -DisplayName $Context.VmName -PublicAddress $Context.TunnelFQDN -MicrosoftTunnelConfiguration @{id = $Context.ServerConfiguration.id } -RoleScopeTagIds @("0") -UpgradeAutomatically
    }

    $script:Context.TunnelSite = $Context.TunnelSite
}

Function Remove-TunnelSite {
    Write-Header "Deleting Site..."
    $Context.TunnelSite = Get-MgDeviceManagementMicrosoftTunnelSite -Filter "displayName eq '$($Context.VmName)'" -Limit 1

    if ($Context.TunnelSite) {
        Remove-MgDeviceManagementMicrosoftTunnelSite -MicrosoftTunnelSiteId $Context.TunnelSite.Id
    }
    else {
        Write-Host "Site '$($Context.VmName)' does not exist."
    }
}

Function Remove-TunnelServers {
    Write-Header "Deleting Servers..."
    $Context.TunnelSite = Get-MgDeviceManagementMicrosoftTunnelSite -Filter "displayName eq '$($Context.VmName)'" -Limit 1

    if ($Context.TunnelSite) {
        $servers = Get-MgDeviceManagementMicrosoftTunnelSiteMicrosoftTunnelServer -MicrosoftTunnelSiteId $Context.TunnelSite.Id

        $servers | ForEach-Object {
            Write-Header "Deleting '$($_.DisplayName)'..."
            Invoke-MgGraphRequest -Method DELETE -Uri "https://graph.microsoft.com/beta/deviceManagement/microsoftTunnelSites/$($Context.TunnelSite.Id)/microsoftTunnelServers/$($_.Id)"
        }
    }
    else {
        Write-Host "No site found for '$($Context.VmName)', so no servers will be deleted."
    }
}

Function Update-PrivateDNSAddress {
    Write-Header "Updating server configuration private DNS..."

    Update-MgDeviceManagementMicrosoftTunnelConfiguration -DnsServers $Context.ProxyIP -MicrosoftTunnelConfigurationId $Context.ServerConfiguration.Id
    $script:Context.ServerConfiguration = Get-MgDeviceManagementMicrosoftTunnelConfiguration -MicrosoftTunnelConfigurationId $Context.ServerConfiguration.Id
}
#endregion Tunnel Server Profiles

#region App Registration Setup
Function New-ServicePrincipal {
    $TunnelServicePrincipal = Get-MgServicePrincipal -Filter "DisplayName eq 'Microsoft Tunnel Gateway'"
    if ($TunnelServicePrincipal) {
        return
    }

    Write-Header "Provisioning Service Principal for Microsoft Tunnel Gateway..."

    try {
        $appId = "3678c9e9-9681-447a-974d-d19f668fcd88"

        New-MgServicePrincipal -AppId $appId
        
        Write-Host "Successfully provisioned the Service Principal" -ForegroundColor Green
    }
    catch [Exception] {
        Write-Error "Error provisioning Service Principal"
        Write-Host $_.Exception.GetType().FullName, $_.Exception.Message
        Write-Host "Failed to provision the Service Principal" -ForegroundColor Red
        exit 1
    }
}
#endregion

#region iOS MAM Specific Functions
Function Update-ADApplication {
    param(
        [string] $ADApplication,
        [string] $TenantId
    )
    
    $App = Get-MgApplication -Filter "DisplayName eq '$ADApplication'" -Limit 1
    if ($App) {
        Write-Success "Client Id: $($App.AppId)"
        Write-Success "Tenant Id: $($TenantId)"

        if ($Context.BundleIds -and $Context.BundleIds.Count -gt 0) {
            Write-Header "Found AD Application '$ADApplication'..."
            $uris = [System.Collections.ArrayList]@()
            foreach ($bundle in $Context.BundleIds) {
                $uri1 = "msauth://code/msauth.$bundle%3A%2F%2Fauth"
                $uri2 = "msauth.$($bundle)://auth"
                if (-Not $App.PublicClient.RedirectUris.Contains($uri1)) {
                    Write-Host "Missing Uri '$uri1' for '$bundle', preparing to add."
                    $uris.Add($uri1) | Out-Null
                }
                if (-Not $App.PublicClient.RedirectUris.Contains($uri2)) {
                    Write-Host "Missing Uri '$uri2' for '$bundle', preparing to add."
                    $uris.Add($uri2) | Out-Null
                }
            }
            if ($uris.Count -gt 0) {
                $newUris = $App.PublicClient.RedirectUris + $uris
                $PublicClient = @{
                    RedirectUris = $newUris
                }

                Write-Header "Updating Redirect URIs..."
                Update-MgApplication -ApplicationId $App.Id -PublicClient $PublicClient
            }
        }
    }
    else {
        Write-Header "Creating AD Application '$ADApplication'..."
        $RequiredResourceAccess = @(
            @{
                ResourceAppId  = "00000003-0000-0000-c000-000000000000"
                ResourceAccess = @(
                    @{
                        Id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
                        Type = "Scope"
                    }
                )
            }
            @{
                ResourceAppId  = "0a5f63c0-b750-4f38-a71c-4fc0d58b89e2"
                ResourceAccess = @(
                    @{
                        Id   = "3c7192af-9629-4473-9276-d35e4e4b36c5"
                        Type = "Scope"
                    }
                )
            }
            @{
                ResourceAppId  = "3678c9e9-9681-447a-974d-d19f668fcd88"
                ResourceAccess = @(
                    @{
                        Id   = "eb539595-3fe1-474e-9c1d-feb3625d1be5"
                        Type = "Scope"
                    }
                )
            }
        )
        
        $OptionalClaims = @{
            IdToken     = @()
            AccessToken = @(
                @{
                    Name                 = "acct"
                    Essential            = $false
                    AdditionalProperties = @()
                }
            )
            Saml2Token  = @()
        }
        $uris = [System.Collections.ArrayList]@()
        foreach ($bundle in $Context.BundleIds) {
            $uris.Add("msauth://code/msauth.$bundle%3A%2F%2Fauth") | Out-Null
            $uris.Add("msauth.$($bundle)://auth") | Out-Null
        }
        $PublicClient = @{
            RedirectUris = $uris
        }
        
        $App = New-MgApplication -DisplayName $ADApplication -RequiredResourceAccess $RequiredResourceAccess -OptionalClaims $OptionalClaims -PublicClient $PublicClient -SignInAudience "AzureADMyOrg"

        Write-Success "Client Id: $($App.AppId)"
        Write-Success "Tenant Id: $($TenantId)"

        Write-Header "You will need to grant consent. Opening browser in 15 seconds..."
        Start-Sleep -Seconds 15
        Start-Process "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/CallAnAPI/appId/$($App.AppId)/isMSAApp~/false"
    }

    return $App
}

Function New-GeneratedXCConfig {
    param(
        [string[]] $bundle,
        [string] $AppId,
        [string] $TenantId

    )
    $Content = @"
CONFIGURED_BUNDLE_IDENTIFIER = $bundle
CONFIGURED_TENANT_ID = $($TenantId)
CONFIGURED_CLIENT_ID = $($AppId)
"@
    Set-Content -Path "./Generated.xcconfig" -Value $Content -Force
}
#endregion iOS MAM Specific Functions

#region Create iOS Functions
Function New-IosAppProtectionPolicy {
    param(
        [string] $DisplayName
    )

    $IosAppProtectionPolicy = Get-MgDeviceAppManagementiOSManagedAppProtection -Filter "displayName eq '$DisplayName'" -Limit 1
    if ($IosAppProtectionPolicy) {
        Write-Host "Already found App Protection policy named '$DisplayName'"
    }
    else {
        Write-Header "Creating App Protection policy '$DisplayName'..."
        $IosAppProtectionPolicy = New-MgDeviceAppManagementiOSManagedAppProtection -DisplayName $DisplayName
        Write-Header "Targeting bundles to '$DisplayName'..."
        $targetedApps = $Context.BundleIds | ForEach-Object { 
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.iosMobileAppIdentifier"
                    bundleId      = $_
                }
            }
        }
        if (-not ($targetedApps -is [array])) {
            $targetedApps = @($targetedApps)
        }
        $body = @{
            apps         = $targetedApps
            appGroupType = "selectedPublicApps"
        } | ConvertTo-Json -Depth 10
        
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($IosAppProtectionPolicy.Id)')/targetApps" -Body $Body
        
        Write-Header "Assigning App Protection policy '$DisplayName' to group '$($Context.Group.DisplayName)'..."
        $Body = @{
            assignments = @(
                @{
                    target = @{
                        groupId                                    = $Context.Group.Id
                        deviceAndAppManagementAssignmentFilterId   = $null
                        deviceAndAppManagementAssignmentFilterType = "none"
                        "@odata.type"                              = "#microsoft.graph.groupAssignmentTarget"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/iosManagedAppProtections('$($IosAppProtectionPolicy.Id)')/assign" -Body $Body
    }

    return $IosAppProtectionPolicy
}

Function New-IosTrustedRootPolicy {
    param(
        [string] $DisplayName
    )

    $IosTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

    if ($IosTrustedRootPolicy) {
        Write-Host "Already found Trusted Root policy named '$DisplayName'"
    }
    else {
        $certFileName = [Constants]::CertFileName
        $certValue = (Get-Content $certFileName).Replace("-----BEGIN CERTIFICATE-----", "").Replace("-----END CERTIFICATE-----", "") -join ""
        
        $Body = @{
            "@odata.type"          = "#microsoft.graph.iosTrustedRootCertificate"
            displayName            = $DisplayName
            id                     = [System.Guid]::Empty.ToString()
            roleScopeTagIds        = @("0")
            certFileName           = "$DisplayName.cer"
            trustedRootCertificate = $certValue
        } | ConvertTo-Json -Depth 10

        Write-Header "Creating Trusted Root Policy..."
        $IosTrustedRootPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body $Body

        # re-fetch the policy so the root certificate is included
        $IosTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
        
        $Body = @{
            "assignments" = @(@{
                    "target" = @{
                        "groupId"     = $Context.Group.Id
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                })
        }
    
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($IosTrustedRootPolicy.Id)/assign" -Body $Body

        return $IosTrustedRootPolicy
    }

    return $IosTrustedRootPolicy
}

Function New-IosDeviceConfigurationPolicy {
    param(
        [string] $DisplayName
    )

    $IosDeviceConfigurationPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

    if ($IosDeviceConfigurationPolicy) {
        Write-Host "Already found Device Configuration policy named '$DisplayName'"
    }
    else {
        Write-Header "Creating Device Configuration policy '$DisplayName'..."
        $Payload = @{
            "@odata.type"         = "#microsoft.graph.iosVpnConfiguration"
            displayName           = $DisplayName
            id                    = [System.Guid]::Empty.ToString()
            roleScopeTagIds       = @("0")
            authenticationMethod  = "UsernameAndPassword"
            connectionType        = "microsoftTunnel"
            connectionName        = $DisplayName
            microsoftTunnelSiteId = $Context.TunnelSite.Id
            server                = @{
                address     = "$($Context.TunnelSite.PublicAddress):$($Context.ServerConfiguration.ListenPort)"
                description = ""
            }
            customData            = @(@{
                    key   = "MSTunnelProtectMode"
                    value = "1"
                })
            enableSplitTunneling  = $false
        }

        if ($Context.PACUrl -ne "" -or $Context.ProxyHostname -ne "") {
            $Payload += @{
                proxyServer = if ($Context.PACUrl -ne "") { @{ automaticConfigurationScriptUrl = "$Context.PACUrl" } } else { @{ address = "$Context.ProxyHostname"; port = $Context.ProxyPort } }
            }
        }

        $Body = $Payload | ConvertTo-Json -Depth 10

        $IosDeviceConfigurationPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body $Body

        $Body = @{
            "assignments" = @(@{
                    "target" = @{
                        "groupId"     = $Context.Group.Id
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                })
        }
    
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($IosDeviceConfigurationPolicy.Id)/assign" -Body $Body
    }

    return $IosDeviceConfigurationPolicy
}

Function New-IosAppConfigurationPolicy {
    param(
        [string] $DisplayName,
        $TrustedRootPolicy
    )

    $IosAppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1 | ConvertFrom-Json
    if ($IosAppConfigurationPolicy) {
        Write-Host "Already found App Configuration policy named '$DisplayName'"
    }
    else {
        Write-Header "Creating App Configuration policy '$DisplayName'..."
        $customSettings = @(
            @{
                name  = "com.microsoft.intune.mam.managedbrowser.TunnelAvailable.IntuneMAMOnly"
                value = "true"
            }
            @{
                name  = "com.microsoft.tunnel.connection_type"
                value = "MicrosoftProtect"
            }
            @{
                name  = "com.microsoft.tunnel.connection_name"
                value = $DisplayName
            }
            @{
                name  = "com.microsoft.tunnel.site_id"
                value = $Context.TunnelSite.Id
            }
            @{
                name  = "com.microsoft.tunnel.server_address"
                value = "$($Context.TunnelSite.PublicAddress):$($Context.ServerConfiguration.ListenPort)"
            }
            @{
                name  = "com.microsoft.tunnel.trusted_root_certificates"
                value = (@(
                        @{
                            "@odata.type"          = $TrustedRootPolicy.AdditionalProperties."@odata.type"
                            id                     = $TrustedRootPolicy.Id
                            displayName            = $TrustedRootPolicy.DisplayName
                            lastModifiedDateTime   = $TrustedRootPolicy.LastModifiedDateTime
                            trustedRootCertificate = $TrustedRootPolicy.AdditionalProperties.trustedRootCertificate
                        }
                    ) | ConvertTo-Json -Depth 10 -Compress -AsArray)
            }
        )

        if ($Context.PACUrl -ne "") {
            $customSettings += @(@{
                    name  = "com.microsoft.tunnel.proxy_pacurl"
                    value = $Context.PACUrl
                })
        }
        elseif ($Context.ProxyHostname -ne "") {
            $customSettings += @( @{
                    name  = "com.microsoft.tunnel.proxy_address"
                    value = $Context.ProxyHostname
                },
                @{
                    name  = "com.microsoft.tunnel.proxy_port"
                    value = $Context.ProxyPort
                })
        }

        $targetedApps = $Context.BundleIds | ForEach-Object { 
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.iosMobileAppIdentifier"
                    bundleId      = $_
                }
            }
        }
        if (-not ($targetedApps -is [array])) {
            $targetedApps = @($targetedApps)
        }
        $body = @{
            apps                        = $targetedApps
            assignments                 = @(
                @{
                    target = @{
                        groupId                                    = $Context.Group.Id
                        deviceAndAppManagementAssignmentFilterId   = $null
                        deviceAndAppManagementAssignmentFilterType = "none"
                        "@odata.type"                              = "#microsoft.graph.groupAssignmentTarget"
                    }
                }
            )
            appGroupType                = "selectedPublicApps"
            customSettings              = $customSettings
            displayName                 = $DisplayName
            description                 = ""
            roleScopeTagIds             = @()
            scSettings                  = @()
            targetedAppManagementLevels = "unspecified"
        } | ConvertTo-Json -Depth 10 -Compress

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/targetedManagedAppConfigurations" -Body $Body | Out-Null
        $IosAppConfigurationPolicy = Get-MgDeviceAppManagementTargetedManagedAppConfiguration -Filter "displayName eq '$DisplayName'" -Limit 1
    }
    
    return $IosAppConfigurationPolicy
}
#endregion Create iOS Functions

#region Create Android Functions
Function New-AndroidTrustedRootPolicy {
    param(
        [string] $DisplayName
    )

    $AndroidTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

    if ($AndroidTrustedRootPolicy) {
        Write-Host "Already found Trusted Root policy named '$DisplayName'"
    }
    else {
        $certFileName = [Constants]::CertFileName
        $certValue = (Get-Content $certFileName).Replace("-----BEGIN CERTIFICATE-----", "").Replace("-----END CERTIFICATE-----", "") -join ""
        
        $Body = @{
            "@odata.type"          = "#microsoft.graph.androidWorkProfileTrustedRootCertificate"
            displayName            = $DisplayName
            id                     = [System.Guid]::Empty.ToString()
            roleScopeTagIds        = @("0")
            certFileName           = "$DisplayName.cer"
            trustedRootCertificate = $certValue
        } | ConvertTo-Json -Depth 10

        Write-Header "Creating Trusted Root Policy..."
        $AndroidTrustedRootPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body $Body

        # re-fetch the policy so the root certificate is included
        $AndroidTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

        $Body = @{
            "assignments" = @(@{
                    "target" = @{
                        "groupId"     = $Context.Group.Id
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                })
        }
    
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($AndroidTrustedRootPolicy.Id)/assign" -Body $Body
    }

    return $AndroidTrustedRootPolicy
}

Function New-AndroidDeviceConfigurationPolicy {
    param(
        [string] $DisplayName
    )

    $AndroidDeviceConfigurationPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

    if ($AndroidDeviceConfigurationPolicy) {
        Write-Host "Already found Device Configuration policy named '$DisplayName'"
    }
    else {
        Write-Header "Creating Device Configuration policy '$DisplayName'..."
        $Payload = @{
            "@odata.type"         = "#microsoft.graph.androidWorkProfileVpnConfiguration"
            displayName           = $DisplayName
            id                    = [System.Guid]::Empty.ToString()
            roleScopeTagIds       = @("0")
            authenticationMethod  = "azureAD"
            connectionType        = "microsoftProtect"
            connectionName        = $DisplayName
            microsoftTunnelSiteId = $Context.TunnelSite.Id
            servers               = @(@{
                    address     = "$($Context.TunnelSite.PublicAddress):$($Context.ServerConfiguration.ListenPort)"
                    description = ""
                })
            customData            = @(@{
                    key   = "MicrosoftDefenderAppSettings"
                    value = $null
                })
        }

        if ($Context.PACUrl -ne "" -or $Context.ProxyHostname -ne "") {
            $Payload += @{
                proxyServer = if ($Context.PACUrl -ne "") { @{ automaticConfigurationScriptUrl = "$Context.PACUrl" } } else { @{ address = "$Context.ProxyHostname"; port = $Context.ProxyPort } }
            }
        }

        $Body = $Payload | ConvertTo-Json -Depth 10

        $AndroidDeviceConfigurationPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" -Body $Body

        $Body = @{
            "assignments" = @(@{
                    "target" = @{
                        "groupId"     = $Context.Group.Id
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    }
                })
        }
    
        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($AndroidDeviceConfigurationPolicy.Id)/assign" -Body $Body
    }

    return $AndroidDeviceConfigurationPolicy
}

Function New-AndroidAppProtectionPolicy {
    param(
        [string] $DisplayName
    )

    $AndroidAppProtectionPolicy = Get-MgDeviceAppManagementAndroidManagedAppProtection -Filter "displayName eq '$DisplayName'"
    if ($AndroidAppProtectionPolicy) {
        Write-Host "Already found App Protection policy named '$DisplayName'"
    }
    else {
        Write-Header "Targeting bundles to '$DisplayName'..."

        $customApps = $Context.BundleIds | ForEach-Object { 
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId     = $_
                }
            }
        }
        if (-not ($customApps -is [array])) {
            $customApps = @($customApps)
        }

        $defaultApps = @(
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId     = "com.microsoft.scmx"
                }
            }
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId     = "com.microsoft.emmx"
                }
            }
        )

        $targetedApps = $customApps + $defaultApps

        $body = @{
            displayName          = $DisplayName
            apps                 = $targetedApps
            appGroupType         = "selectedPublicApps"
            connectToVpnOnLaunch = $true
        } | ConvertTo-Json -Depth 10
        
        Write-Header "Creating App Protection policy '$DisplayName'..."
        $AndroidAppProtectionPolicy = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections" -Body $Body
        
        Write-Header "Assigning App Protection policy '$DisplayName' to group '$($Context.Group.DisplayName)'..."
        $Body = @{
            assignments                 = @(
                @{
                    target = @{
                        groupId                                    = $Context.Group.Id
                        deviceAndAppManagementAssignmentFilterId   = $null
                        deviceAndAppManagementAssignmentFilterType = "none"
                        "@odata.type"                              = "#microsoft.graph.groupAssignmentTarget"
                    }
                }
            )
            appGroupType                = "selectedPublicApps"
            customSettings              = $customSettings
            displayName                 = $DisplayName
            description                 = ""
            roleScopeTagIds             = @()
            scSettings                  = @()
            targetedAppManagementLevels = "unspecified"
        } | ConvertTo-Json -Depth 10 -Compress

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/androidManagedAppProtections('$($AndroidAppProtectionPolicy.Id)')/assign" -Body $Body
    }

    return $AndroidAppProtectionPolicy
}

Function New-AndroidAppConfigurationPolicy {
    param(
        [string] $DisplayName,
        $TrustedRootPolicy
    )

    $AndroidAppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1
    if ($AndroidAppConfigurationPolicy) {
        Write-Host "Already found App Configuration policy named '$DisplayName'"
    }
    else {
        Write-Header "Creating App Configuration policy '$DisplayName'..."


        $perApps = ""
        if ($Context.BundleIds.Count -eq 0) {
            $perApps = ""
        }
        elseif ($Context.BundleIds.Count -eq 1) {
            $perApps = $Context.BundleIds[0]
        }
        else {
            $Context.BundleIds | ForEach-Object { 
                $perApps = $perApps + "|" + $_
            }
        }

        $customSettings = @(
            @{
                name  = "com.microsoft.intune.mam.managedbrowser.TunnelAvailable.IntuneMAMOnly"
                value = "true"
            }
            @{
                name  = "com.microsoft.tunnel.connection_type"
                value = "MicrosoftProtect"
            }
            @{
                name  = "com.microsoft.tunnel.connection_name"
                value = $DisplayName
            }
            @{
                name  = "com.microsoft.tunnel.site_id"
                value = $Context.TunnelSite.Id
            }
            @{
                name  = "com.microsoft.tunnel.server_address"
                value = "$($Context.TunnelSite.PublicAddress):$($Context.ServerConfiguration.ListenPort)"
            }
            @{
                name  = "com.microsoft.tunnel.targeted_apps"
                value = $perApps
            }
            @{
                name  = "com.microsoft.tunnel.trusted_root_certificates"
                value = (@(
                        @{
                            "@odata.type"          = $TrustedRootPolicy.AdditionalProperties."@odata.type"
                            id                     = $TrustedRootPolicy.Id
                            displayName            = $TrustedRootPolicy.DisplayName
                            lastModifiedDateTime   = $TrustedRootPolicy.LastModifiedDateTime
                            trustedRootCertificate = $TrustedRootPolicy.AdditionalProperties.trustedRootCertificate
                        }
                    ) | ConvertTo-Json -Depth 10 -Compress -AsArray)
            }
        )

        if ($Context.PACUrl -ne "") {
            $customSettings += @(@{
                    name  = "com.microsoft.tunnel.proxy_pacurl"
                    value = $Context.PACUrl
                })
        }
        elseif ($Context.ProxyHostname -ne "") {
            $customSettings += @( @{
                    name  = "com.microsoft.tunnel.proxy_address"
                    value = $Context.ProxyHostname
                },
                @{
                    name  = "com.microsoft.tunnel.proxy_port"
                    value = $Context.ProxyPort
                })
        }

        $customApps = $Context.BundleIds | ForEach-Object { 
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId     = $_
                }
            }
        }
        if (-not ($customApps -is [array])) {
            $customApps = @($customApps)
        }

        $defaultApps = @(
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId     = "com.microsoft.scmx"
                }
            }
            @{
                mobileAppIdentifier = @{
                    "@odata.type" = "#microsoft.graph.androidMobileAppIdentifier"
                    packageId     = "com.microsoft.emmx"
                }
            }
        )

        $targetedApps = $customApps + $defaultApps

        $body = @{
            apps                        = $targetedApps
            assignments                 = @(
                @{
                    target = @{
                        groupId                                    = $Context.Group.Id
                        deviceAndAppManagementAssignmentFilterId   = $null
                        deviceAndAppManagementAssignmentFilterType = "none"
                        "@odata.type"                              = "#microsoft.graph.groupAssignmentTarget"
                    }
                }
            )
            appGroupType                = "selectedPublicApps"
            customSettings              = $customSettings
            displayName                 = $DisplayName
            description                 = ""
            roleScopeTagIds             = @()
            scSettings                  = @()
            targetedAppManagementLevels = "unspecified"
        } | ConvertTo-Json -Depth 10 -Compress

        Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceAppManagement/targetedManagedAppConfigurations" -Body $Body | Out-Null
        $AndroidAppConfigurationPolicy = Get-MgDeviceAppManagementTargetedManagedAppConfiguration -Filter "displayName eq '$DisplayName'" -Limit 1
    }

    return $AndroidAppConfigurationPolicy
}
#endregion Create Android Functions

#region Remove Functions
Function Remove-IosAppProtectionPolicy {
    param(
        [string] $DisplayName
    )
    
    Write-Header "Deleting App Protection Policy '$DisplayName'..."
    $IosAppProtectionPolicy = Get-MgDeviceAppManagementiOSManagedAppProtection -Filter "displayName eq '$DisplayName'" -Limit 1
    if ($IosAppProtectionPolicy) {
        Remove-MgDeviceAppManagementiOSManagedAppProtection -IosManagedAppProtectionId $IosAppProtectionPolicy.Id
    }
    else {
        Write-Host "App Protection Policy '$DisplayName' does not exist."
    }
}

Function Remove-IosTrustedRootPolicy {
    param(
        [string] $DisplayName
    )

    Write-Header "Deleting Trusted Root Policy '$DisplayName'..."

    $IosTrustedRootPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

    if ($IosTrustedRootPolicy) {
        Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $IosTrustedRootPolicy.Id
    }
    else {
        Write-Host "Trusted Root Policy '$DisplayName' does not exist."
    }
}

Function Remove-IosDeviceConfigurationPolicy {
    param(
        [string] $DisplayName
    )

    Write-Header "Deleting Device Configuration Policy '$DisplayName'..."

    $IosDeviceConfigurationPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"

    if ($IosDeviceConfigurationPolicy) {
        Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $IosDeviceConfigurationPolicy.Id
    }
    else {
        Write-Host "Device Configuration Policy '$DisplayName' does not exist."
    }
}

Function Remove-IosAppConfigurationPolicy {
    param(
        [string] $DisplayName
    )
    
    Write-Header "Deleting App Configuration Policy '$DisplayName'..."
    
    $IosAppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1
    
    if ($IosAppConfigurationPolicy) {
        Remove-MgDeviceAppManagementManagedAppPolicy -ManagedAppPolicyId $IosAppConfigurationPolicy.Id
    }
    else {
        Write-Host "App Configuration Policy '$DisplayName' does not exist."
    }
}

Function Remove-AndroidTrustedRootPolicy {
    param(
        [string] $DisplayName
    )

    Write-Header "Deleting Device Configuration Policy '$DisplayName'..."
    
    $AndroidDeviceConfigurationPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
    
    if ($AndroidDeviceConfigurationPolicy) {
        Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $AndroidDeviceConfigurationPolicy.Id
    }
    else {
        Write-Host "Device Configuration Policy '$DisplayName' does not exist."
    }
}

Function Remove-AndroidDeviceConfigurationPolicy {
    param(
        [string] $DisplayName
    )
    
    Write-Header "Deleting Device Configuration Policy '$DisplayName'..."
    
    $AndroidDeviceConfigurationPolicy = Get-MgDeviceManagementDeviceConfiguration -Filter "displayName eq '$DisplayName'"
    
    if ($AndroidDeviceConfigurationPolicy) {
        Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $AndroidDeviceConfigurationPolicy.Id
    }
    else {
        Write-Host "Device Configuration Policy '$DisplayName' does not exist."
    }
}

Function Remove-AndroidAppProtectionPolicy {
    param(
        [string] $DisplayName
    )
    
    Write-Header "Deleting App Protection Policy '$DisplayName'..."
    
    $AndroidAppProtectionPolicy = Get-MgDeviceAppManagementAndroidManagedAppProtection -Filter "displayName eq '$DisplayName'" -Limit 1
    
    if ($AndroidAppProtectionPolicy) {
        Remove-MgDeviceAppManagementAndroidManagedAppProtection -AndroidManagedAppProtectionId $AndroidAppProtectionPolicy.Id
    }
    else {
        Write-Host "App Protection Policy '$DisplayName' does not exist."
    }
}

Function Remove-AndroidAppConfigurationPolicy {
    param(
        [string] $DisplayName
    )
    
    Write-Header "Deleting App Configuration Policy '$DisplayName'..."
    
    $AndroidAppConfigurationPolicy = Get-MgDeviceAppManagementManagedAppPolicy -Filter "displayName eq '$DisplayName'" -Limit 1
    
    if ($AndroidAppConfigurationPolicy) {
        Remove-MgDeviceAppManagementManagedAppPolicy -ManagedAppPolicyId $AndroidAppConfigurationPolicy.Id
    }
    else {
        Write-Host "App Configuration Policy '$DisplayName' does not exist."
    }
}
#endregion Remove Functions

#region Scenario Functions
Function New-IosProfiles {
    param(
        [string] $certFileName
    )

    $IosDeviceConfigurationPolicy = New-IosDeviceConfigurationPolicy -DisplayName "ios-$($Context.VmName)-DC"
    $IosAppProtectionPolicy = New-IosAppProtectionPolicy -DisplayName "ios-$($Context.VmName)-APP"
    $IosTrustedRootPolicy = New-IosTrustedRootPolicy -DisplayName "ios-$($Context.VmName)-TR"
    $IosAppConfigurationPolicy = New-IosAppConfigurationPolicy -DisplayName "ios-$($Context.VmName)-appconfig" -TrustedRootPolicy $IosTrustedRootPolicy
}

Function Remove-IosProfiles {
    Remove-IosDeviceConfigurationPolicy -DisplayName "ios-$($Context.VmName)-DC"
    Remove-IosAppConfigurationPolicy -DisplayName "ios-$($Context.VmName)-appconfig"
    Remove-IosAppProtectionPolicy -DisplayName "ios-$($Context.VmName)-APP"
    Remove-IosTrustedRootPolicy -DisplayName "ios-$($Context.VmName)-TR"
}

Function New-AndroidProfiles {
    param(
        [string] $certFileName
    )

    $AndroidDeviceConfigurationPolicy = New-AndroidDeviceConfigurationPolicy -DisplayName "android-$($Context.VmName)-DC"
    $AndroidAppProtectionPolicy = New-AndroidAppProtectionPolicy -DisplayName "android-$($Context.VmName)-APP"
    $AndroidTrustedRootPolicy = New-AndroidTrustedRootPolicy -DisplayName "android-$($Context.VmName)-TR"
    $AndroidAppConfigurationPolicy = New-AndroidAppConfigurationPolicy -DisplayName "android-$($Context.VmName)-appconfig" -TrustedRootPolicy $AndroidTrustedRootPolicy
}

Function Remove-AndroidProfiles {
    Remove-AndroidDeviceConfigurationPolicy -DisplayName "android-$($Context.VmName)-DC"
    Remove-AndroidAppConfigurationPolicy -DisplayName "android-$($Context.VmName)-appconfig"
    Remove-AndroidAppProtectionPolicy -DisplayName "android-$($Context.VmName)-APP"
    Remove-AndroidTrustedRootPolicy -DisplayName "android-$($Context.VmName)-TR"
}
#endregion Scenario Functions