# Build full RustDesk Windows Flutter client (NOT agent-bg test binary).
# Usage:
#   cd D:\iGame+\rustdesk
#   .\scripts\build-windows.ps1
# Output (main):
#   flutter\build\windows\x64\runner\Release\rustdesk.exe
#   target\release\librustdesk.dll

param(
    [string] $FlutterRoot = "",
    [string] $VcpkgRoot = "",
    [string] $LlvmRoot = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location $RepoRoot

if (-not $VcpkgRoot) { $VcpkgRoot = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { "D:\iGame+\vcpkg" } }
. (Join-Path $PSScriptRoot "Enter-RustdeskBuildEnv.ps1") -FlutterRoot $FlutterRoot -VcpkgRoot $VcpkgRoot -LlvmRoot $LlvmRoot

if (-not (Test-Path -LiteralPath (Join-Path $env:LIBCLANG_PATH "libclang.dll"))) {
    Write-Error "libclang.dll missing under LIBCLANG_PATH=$env:LIBCLANG_PATH"
}

foreach ($d in @(
        "$env:LocalAppData\Programs\Python\Python313",
        "$env:LocalAppData\Programs\Python\Python312"
    )) {
    $px = Join-Path $d "python.exe"
    if (Test-Path $px) {
        $env:PATH = "$d;$(Join-Path $d 'Scripts');$env:PATH"
        $pythonExe = $px
        break
    }
}
if (-not $pythonExe) {
    $g = Get-Command python -ErrorAction SilentlyContinue
    if ($g) { $pythonExe = $g.Source } else { Write-Error "python.exe not found" }
}

Write-Host "Building full RustDesk client (Flutter)..."
Write-Host "$pythonExe build.py --portable --flutter --skip-portable-pack"
& $pythonExe build.py --portable --flutter --skip-portable-pack
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$client = Join-Path $RepoRoot "flutter\build\windows\x64\runner\Release\rustdesk.exe"
Write-Host ""
Write-Host "Done. Main client:"
Write-Host "  $client"
if (Test-Path $client) {
    Write-Host "  Size: $((Get-Item $client).Length) bytes"
} else {
    Write-Warning "rustdesk.exe not found at expected path; check build.py output above."
}
