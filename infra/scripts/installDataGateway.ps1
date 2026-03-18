param(
  [Parameter(Mandatory = $true)]
  [string] $gatewayName,

  # Keep as string for simple CLI usage; we convert to SecureString later in pwsh.
  [Parameter(Mandatory = $true)]
  [string] $recoveryKey,

  [Parameter(Mandatory = $true)]
  [string] $baseName,

  [Parameter(Mandatory = $true)]
  [string] $userObjectId,

  [Parameter(Mandatory = $true)]
  [string] $appId,

  [Parameter(Mandatory = $true)]
  [string] $tenantId
)

# =========================
# 0) Self-bootstrap to pwsh (PowerShell 7.4+)
# =========================
function Get-PwshPath {
  $candidates = @(
    Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
    Join-Path $env:ProgramFiles 'PowerShell\7-preview\pwsh.exe'
  )
  foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
  return $null
}

function Ensure-Pwsh74 {
  # DataGateway module requires PowerShell 7+ (and your installed module version requires 7.4.0 per error). [4](https://www.codestudy.net/blog/install-winget-by-the-command-line-powershell/)[5](https://bing.com/search?q=winget+install+PowerShell)
  $min = [version]'7.4.0'
  $pwsh = Get-PwshPath

  if ($pwsh) {
    # If pwsh exists, ensure version is >= 7.4.0
    $v = & $pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null
    if ($v) {
      try { if ([version]$v -ge $min) { return $pwsh } } catch { }
    }
  }

  # If we're already in pwsh but too old, fail early
  if ($PSVersionTable.PSEdition -eq 'Core') {
    throw "pwsh is present but version $($PSVersionTable.PSVersion) is < $min"
  }

  # We're in Windows PowerShell 5.1 (Desktop). Install PowerShell 7 via MSI silently. [1](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows?view=powershell-7.5)
  $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }

  # Pick an MSI. Microsoft Learn shows MSI names/versions and that MSI installs can be done silently. [1](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows?view=powershell-7.5)
  # You can update the version if needed; this should be a stable MSI from GitHub release assets.
  $psVersion = '7.5.5'
  $msiName   = "PowerShell-$psVersion-win-$arch.msi"
  $msiUri    = "https://github.com/PowerShell/PowerShell/releases/download/v$psVersion/$msiName"
  $msiPath   = Join-Path $env:TEMP $msiName

  Write-Host "Installing PowerShell $psVersion ($arch) from MSI: $msiUri"
  Invoke-WebRequest -Uri $msiUri -OutFile $msiPath

  # Silent MSI install example and properties are documented by Microsoft. [1](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows?view=powershell-7.5)
  $args = @(
    "/package `"$msiPath`"",
    "/quiet",
    "ADD_PATH=1",
    "ENABLE_PSREMOTING=1",
    "REGISTER_MANIFEST=1",
    "USE_MU=1",
    "ENABLE_MU=1",
    "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1",
    "ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1"
  )
  Start-Process -FilePath "msiexec.exe" -ArgumentList $args -Wait

  $pwsh = Get-PwshPath
  if (-not $pwsh) {
    throw "pwsh.exe not found after MSI install. Expected under $env:ProgramFiles\PowerShell\7\pwsh.exe"
  }
  return $pwsh
}

# Relaunch in pwsh if needed
if ($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion -lt [version]'7.4.0') {
  $pwsh = Ensure-Pwsh74
  # Prevent infinite recursion if something odd happens
  if (-not $env:BOOTSTRAPPED_PWSH) { $env:BOOTSTRAPPED_PWSH = "1" }

  & $pwsh -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath `
    -gatewayName $gatewayName `
    -recoveryKey $recoveryKey `
    -baseName $baseName `
    -userObjectId $userObjectId `
    -appId $appId `
    -tenantId $tenantId

  exit $LASTEXITCODE
}

# =========================
# 1) From here we are in pwsh 7.4+
# =========================

# -------------------------
# Logging (keep your approach)
# -------------------------
$logPath = Join-Path $PWD 'tracelog.log'
"Start to execute installDataGateway1.ps1.`n" | Out-File $logPath

function Now-Value() { (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }

function Trace-Log([string] $msg) {
  $now = Now-Value
  try { "${now} $msg`n" | Out-File $logPath -Append } catch { }
}

function Download-Gateway([string] $url, [string] $gwPath) {
  try {
    $ErrorActionPreference = "Stop"
    Invoke-WebRequest -Uri $url -OutFile $gwPath
    Trace-Log "Download gateway successfully. Gateway loc: $gwPath"
  } catch {
    Trace-Log "Fail to download GatewayInstall.exe"
    Trace-Log $_.Exception.ToString()
    throw
  }
}

Trace-Log "Log file: $logPath"

# -------------------------
# 2) Ensure DataGateway module available
# -------------------------
# Microsoft documents these cmdlets as part of the DataGateway module. [4](https://www.codestudy.net/blog/install-winget-by-the-command-line-powershell/)[5](https://bing.com/search?q=winget+install+PowerShell)
if (-not (Get-Module -ListAvailable -Name DataGateway)) {
  Trace-Log "Installing PowerShell module DataGateway"
  Install-Module -Name DataGateway -Scope AllUsers -Force
}
Import-Module DataGateway -ErrorAction Stop

if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
  Trace-Log "Installing PowerShell module Az.Accounts"
  Install-Module Az.Accounts -Scope AllUsers -AllowClobber -Force
}
Import-Module Az.Accounts -ErrorAction Stop

if (-not (Get-Module -ListAvailable -Name Az.KeyVault)) {
  Trace-Log "Installing PowerShell module Az.KeyVault"
  Install-Module Az.KeyVault -Scope AllUsers -AllowClobber -Force
}
Import-Module Az.KeyVault -ErrorAction Stop


# -------------------------
# 3) Get Certificate from Key Vault
# -------------------------
Trace-Log "Connect to Azure"
Connect-AzAccount -Identity
$kvname= "kv$baseName"
$datagatewayCertificateSecretName="DATA-GATEWAY-CERTIFICATE"
$datagatewayCertificatePasswordSecretName="DATA-GATEWAY-CERTIFICATE-PASSWORD"


$pfxBase64 = Get-AzKeyVaultSecret `
  -VaultName "$kvname" `
  -Name "$datagatewayCertificateSecretName" `
  -AsPlainText

$pfxBytes = [Convert]::FromBase64String($pfxBase64)
$pfxBytes
[IO.File]::WriteAllBytes("C:\temp\dg.pfx", $pfxBytes)

$datagatewayCertificatePassword = Get-AzKeyVaultSecret `
  -VaultName "$kvname" `
  -Name "$datagatewayCertificatePasswordSecretName" `
  -AsPlainText

Import-PfxCertificate `
  -FilePath C:\temp\dg.pfx `
  -CertStoreLocation Cert:\LocalMachine\My `
  -Password (ConvertTo-SecureString $datagatewayCertificatePassword -AsPlainText -Force)

Remove-Item C:\temp\dg.pfx


# -------------------------
# 4) Authenticate (required before Get-DataGatewayAccessToken)
# -------------------------
# Doc: log in first using Connect-DataGatewayServiceAccount before Get-DataGatewayAccessToken. [2](https://www.advancedinstaller.com/install-msi-files-with-powershell.html)[3](https://stackoverflow.com/questions/74166150/install-winget-by-the-command-line-powershell)
Trace-Log "Connect to Data Gateway service account"
$thumb = (Get-ChildItem Cert:\LocalMachine\My |
  Where-Object Subject -like "*DataGateway-SP*").Thumbprint
$appId = "799926eb-f414-4902-9b12-88976d4631a2"
$tenantId = "9a1ed33b-f639-47ca-aea1-326c597593be"

Trace-Log "Connection to service"
Connect-DataGatewayServiceAccount `
  -ApplicationId "$appId" `
  -CertificateThumbprint $thumb `
  -Tenant "$tenantId" | Out-Null


Trace-Log "Check connection to service"
Get-DataGatewayAccessToken | Out-Null

# -------------------------
# 4) Download and install gateway, then register cluster
# -------------------------
# Installer URL you used before
$uri = "https://download.microsoft.com/download/d/a/1/da1fddb8-6da8-4f50-b4d0-18019591e182/GatewayInstall.exe"
$installerLocation = Join-Path $PWD "GatewayInstall.exe"

Trace-Log "Gateway download link: $uri"
Trace-Log "Gateway download location: $installerLocation"
Download-Gateway $uri $installerLocation

Trace-Log "Install Data Gateway"
# Install-DataGateway cmdlet is documented by Microsoft. arn.microsoft.com/en-us/powershell/module/datagateway/install-datagateway?view=datagateway-ps)
Install-DataGateway -InstallerLocation $installerLocation -AcceptConditions
Trace-Log "Install Data Gateway successfully, start to add cluster"

Trace-Log "Register Data Gateway"
Add-DataGatewayCluster `
  -GatewayName $gatewayName `
  -RecoveryKey (ConvertTo-SecureString $recoveryKey -AsPlainText -Force)

Trace-Log "Register Data Gateway successfully"
Write-Host "Gateway installed and cluster created: $gatewayName"
Write-Host "Log: $logPath"


# -------------------------
# 5) Add users as administrators to the cluster (optional, but recommended for management access)
# -------------------------
$cluster = Get-DataGatewayCluster | Where-Object Name -eq $gatewayName
$cluster.Id

$gatewayClusterId = [Guid]$cluster.Id

# List of Entra object IDs (users, service principals) to grant Admin
$adminObjectIds = @(
  "$userObjectId"
)

foreach ($oid in $adminObjectIds) {
  Add-DataGatewayClusterUser `
    -GatewayClusterId $gatewayClusterId `
    -PrincipalObjectId ([Guid]$oid) `
    -AllowedDataSourceTypes $null `
    -Role Admin
}
