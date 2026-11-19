param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_.:-]+$')]
    [string]$DeviceId
)

$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
try {
    & "$PSScriptRoot/build_android.ps1" -ValidateOnly
    $logDirectory = Join-Path (Get-Location) 'build'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $logFile = Join-Path $logDirectory ('phone-debug-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
    Write-Host "Debug log: $logFile"
    & flutter run --debug --no-pub -t lib/main.dart -d $DeviceId --dart-define-from-file=dart_defines.json 2>&1 | Tee-Object -FilePath $logFile
    if ($LASTEXITCODE -ne 0) { throw "Phone run failed. Inspect $logFile before retrying." }
} finally {
    Pop-Location
}
