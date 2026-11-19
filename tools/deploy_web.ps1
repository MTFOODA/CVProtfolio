param([string]$ShareBaseUrl = '')
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    $buildArguments = @('build', 'web', '--release', '--no-wasm-dry-run')
    if ($ShareBaseUrl) {
        $parsed = [Uri]$ShareBaseUrl
        if (-not $parsed.IsAbsoluteUri -or $parsed.Scheme -ne 'https') {
            throw 'ShareBaseUrl must be an absolute HTTPS URL.'
        }
        $buildArguments += "--dart-define=SHARE_BASE_URL=$($ShareBaseUrl.TrimEnd('/'))"
    }
    & flutter @buildArguments
    if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }
    & npx.cmd --yes --node-options=--dns-result-order=ipv4first wrangler deploy --keep-vars
    if ($LASTEXITCODE -ne 0) { throw 'Cloudflare deployment failed.' }
} finally {
    Pop-Location
}
