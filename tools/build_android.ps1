param(
    [ValidateSet('Debug', 'Release')]
    [string]$Mode = 'Release',
    [string]$ConfigPath = 'dart_defines.json',
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not [IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath = Join-Path $projectRoot $ConfigPath
}
if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw 'Missing build configuration. Copy dart_defines.example.json to dart_defines.json and fill in the public client values.'
}
$configFile = (Resolve-Path -LiteralPath $ConfigPath).Path
$config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
$allowed = @('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'GOOGLE_WEB_CLIENT_ID', 'GOOGLE_IOS_CLIENT_ID', 'SHARE_BASE_URL', '_comment')
foreach ($property in $config.PSObject.Properties) {
    if ($property.Name -notin $allowed) {
        throw 'Unrecognized build setting. Only public client settings from dart_defines.example.json are allowed.'
    }
}
foreach ($key in @('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'GOOGLE_WEB_CLIENT_ID', 'SHARE_BASE_URL')) {
    $value = [string]$config.$key
    if ([string]::IsNullOrWhiteSpace($value) -or $value.Contains('YOUR_')) {
        throw "Missing public client setting: $key. Refusing to build an offline APK."
    }
}
$shareUri = $null
if (-not [Uri]::TryCreate([string]$config.SHARE_BASE_URL, [UriKind]::Absolute, [ref]$shareUri) -or
    $shareUri.Scheme -ne 'https' -or $shareUri.Host.EndsWith('.example.com')) {
    throw 'SHARE_BASE_URL must name the real HTTPS portfolio host. Refusing to build broken share links.'
}
Write-Host 'Connected Android build configuration is present. Google uses the Web client ID as serverClientId.'
if ($ValidateOnly) { return }

Push-Location -LiteralPath $projectRoot
try {
    & flutter build apk "--$($Mode.ToLowerInvariant())" "--dart-define-from-file=$configFile"
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
    Write-Host "APK: build/app/outputs/flutter-apk/app-$($Mode.ToLowerInvariant()).apk"
} finally {
    Pop-Location
}
