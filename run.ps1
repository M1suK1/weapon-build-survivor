# Launch the game for manual play-testing (no bot, no auto pick).
#
#   .\run.ps1                    random seed
#   .\run.ps1 -Seed 20250518     fixed seed, reproducible
#   .\run.ps1 -ShowDebug         open the F3 debug panel at start
#
# Godot prints "Failed to read the root certificate store." to stderr on this
# machine (broken schannel, same reason git needs http.sslBackend=openssl).
# It is harmless noise: the game does not use the network.
param(
    [int]$Seed = 0,
    [switch]$ShowDebug,
    [string]$Resolution = "1280x720"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$env:APPDATA = Join-Path $root ".tools\appdata"

$exe = Join-Path $root ".tools\godot\Godot_v4.7.2-stable_win64.exe"
if (-not (Test-Path $exe)) {
    Write-Error "Engine not found: $exe"
}

$gameArgs = @("--path", ".", "--resolution", $Resolution, "--")
if ($Seed -ne 0) { $gameArgs += "seed=$Seed" }
if ($ShowDebug) { $gameArgs += "shotdbg" }

Start-Process -FilePath $exe -ArgumentList $gameArgs
Write-Host ("started: seed=" + $(if ($Seed -ne 0) { $Seed } else { "random" }))
