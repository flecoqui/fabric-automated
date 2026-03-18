param(
  # Documented on the Add-DataGatewayCluster help page
  [Parameter(Mandatory = $true)]
  [string]
  $gatewayName

  # Documented on the Add-DataGatewayCluster help page
  [Parameter(Mandatory = $true)]
  [SecureString]
  $recoveryKey
)

# init log setting
$logPath = "$PWD\tracelog.log"
"Start to execute installDataGateway.ps1. `n" | Out-File $logPath

function Now-Value()
{
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Throw-Error([string] $msg)
{
	try
	{
		throw $msg
	}
	catch
	{
		$stack = $_.ScriptStackTrace
		Trace-Log "DMDTTP is failed: $msg`nStack:`n$stack"
	}

	throw $msg
}

function Trace-Log([string] $msg)
{
    $now = Now-Value
    try
    {
        "${now} $msg`n" | Out-File $logPath -Append
    }
    catch
    {
        #ignore any exception during trace
    }

}

function Download-Gateway([string] $url, [string] $gwPath)
{
    try
    {
        $ErrorActionPreference = "Stop";
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($url, $gwPath)
        Trace-Log "Download gateway successfully. Gateway loc: $gwPath"
    }
    catch
    {
        Trace-Log "Fail to download GatewayInstall.exe"
        Trace-Log $_.Exception.ToString()
        throw
    }
}

Trace-Log "Log file: $logPath"


$uri = "https://download.microsoft.com/download/d/a/1/da1fddb8-6da8-4f50-b4d0-18019591e182/GatewayInstall.exe"
Trace-Log "Gateway download link: $uri"
$installerLocation= "$PWD\GatewayInstall.exe"
Trace-Log "Gateway download location: $installerLocation"
Download-Gateway $uri $installerLocation

Trace-Log "Check connection to service"
# Thrown an error if not logged in
Get-DataGatewayAccessToken | Out-Null

Trace-Log "Install Data Gateway"
Install-DataGateway `
  -InstallerLocation $installerLocation `
  -AcceptConditions
Trace-Log "Install Data Gateway successfully, start to add cluster"

Trace-Log "Register Data Gateway"
Add-DataGatewayCluster `
  -GatewayName $gatewayName `
  -RecoveryKey (ConvertTo-SecureString $recoveryKey -AsPlainText -Force)
Trace-Log "Register Data Gateway successfully"
