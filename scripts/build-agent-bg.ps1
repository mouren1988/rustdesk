# Build and optionally run tools/agent-bg (no-window Windows background test).
# Usage:
#   .\scripts\build-agent-bg.ps1
#   .\scripts\build-agent-bg.ps1 -Run

param([switch] $Run)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$ExeRelease = Join-Path $RepoRoot "target\release\agent-bg.exe"

Set-Location $RepoRoot
Write-Host "Building agent-bg (release)..."
cargo build -p agent-bg --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OK: $ExeRelease"
Write-Host "Log file: $env:PROGRAMDATA\RustDeskAgentTest\logs\agent-bg.log"

if ($Run) {
    Write-Host "Starting agent-bg in background (no window)..."
    Start-Process -FilePath $ExeRelease -WindowStyle Hidden
    Write-Host "Check Task Manager for agent-bg.exe; stop with: Stop-Process -Name agent-bg -Force"
}
