Set-Location ..

$AuthenticatedProxyCredentials = Get-Credential -Message "Enter your proxy credentials"

./CreateServer.ps1 -AuthenticatedProxyCredentials @($AuthenticatedProxyCredentials)

Set-Location examples