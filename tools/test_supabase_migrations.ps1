param([string]$PostgresBin = 'C:/Program Files/PostgreSQL/18/bin', [switch]$SetupBundle)
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('cv-supabase-test-' + [guid]::NewGuid().ToString('N'))
$dataPath = Join-Path $testRoot 'data'
$workspace = Split-Path $PSScriptRoot -Parent
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$listener.Start()
$testPort = $listener.LocalEndpoint.Port
$listener.Stop()
$started = $false
function Invoke-Pg([string]$Program, [string[]]$Arguments) {
    & (Join-Path $PostgresBin ($Program + '.exe')) @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program exited with $LASTEXITCODE" }
}
try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    Invoke-Pg 'initdb' @('-D', $dataPath, '-U', 'postgres', '-A', 'trust', '--no-locale', '-E', 'UTF8')
    Invoke-Pg 'pg_ctl' @('-D', $dataPath, '-l', (Join-Path $testRoot 'server.log'), '-o', "-h 127.0.0.1 -p $testPort", '-w', 'start')
    $started = $true
    $psqlArgs = @('-X', '-h', '127.0.0.1', '-p', "$testPort", '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1')
    Invoke-Pg 'psql' ($psqlArgs + @('-f', (Join-Path $workspace 'supabase/tests/bootstrap.sql')))
    if ($SetupBundle) {
        # Test the manual file on a fresh schema, then verify safe re-execution.
        foreach ($pass in 1..2) {
            Write-Output "Applying manual setup (pass $pass)"
            Invoke-Pg 'psql' ($psqlArgs + @('-f', (Join-Path $workspace 'supabase/setup.sql')))
        }
    } else {
        foreach ($file in (Get-ChildItem (Join-Path $workspace 'supabase/migrations/*.sql') | Sort-Object Name)) {
            Write-Output "Applying $($file.Name)"
            Invoke-Pg 'psql' ($psqlArgs + @('--single-transaction', '-f', $file.FullName))
        }
    }
    Invoke-Pg 'psql' ($psqlArgs + @('-f', (Join-Path $workspace 'supabase/tests/access.sql')))
} finally {
    if ($started) { Invoke-Pg 'pg_ctl' @('-D', $dataPath, '-m', 'fast', '-w', 'stop') }
    # Remove only this script's uniquely named directory beneath the OS temp root.
    $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if ($resolvedRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path $resolvedRoot -Leaf) -match '^cv-supabase-test-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
    }
}
