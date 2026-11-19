param(
    [ValidatePattern('^[a-z]{20}$')]
    [string]$ProjectRef = 'shwjiytgrgbpleoljcnk'
)

$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)
try {
    & node --test supabase/functions/share-media/index_test.mjs
    if ($LASTEXITCODE -ne 0) { throw 'Media authorization tests failed. Deployment stopped.' }
    # This visitor endpoint verifies the slug/password/token through the
    # existing share RPC before signing any visible, owner-scoped object.
    # Pin the CLI because v3 replaced --project-ref with --remote.
    & npx.cmd --yes supabase@3.2.0 functions deploy share-media "--remote=$ProjectRef" --no-verify-jwt --use-api --yes
    if ($LASTEXITCODE -ne 0) {
        throw 'Media deployment failed. Authenticate locally with npx.cmd --yes supabase@3.2.0 login and retry. Never paste your token into chat.'
    }
} finally {
    Pop-Location
}
