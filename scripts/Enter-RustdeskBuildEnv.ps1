# Dot-source: . D:\iGame+\rustdesk\scripts\Enter-RustdeskBuildEnv.ps1
# Optional: -LlvmRoot "C:\Program Files\LLVM"

param(
    [string] $FlutterRoot = "",
    [string] $VcpkgRoot = "",
    [string] $LlvmRoot = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent

function Find-LlvmRoot {
    param([string] $Prefer)
    if ($Prefer -and (Test-Path -LiteralPath (Join-Path $Prefer "bin\libclang.dll"))) {
        return $Prefer
    }
    foreach ($c in @(
            $env:LLVM_HOME,
            $env:LIBCLANG_PATH,
            "C:\Program Files\LLVM",
            "C:\Program Files\LLVM-22",
            "C:\Program Files\LLVM-22.1.4-win64",
            "C:\Program Files\LLVM-18",
            "C:\Program Files\LLVM-17",
            "D:\LLVM-22.1.4-win64",
            "D:\LLVM",
            "D:\iGame+\LLVM-22.1.4-win64"
        )) {
        if (-not $c) { continue }
        $root = $c
        if ($root -match '\\bin$') { $root = Split-Path $root -Parent }
        if (Test-Path -LiteralPath (Join-Path $root "bin\libclang.dll")) { return $root }
    }
    foreach ($pf in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "D:\")) {
        if (-not $pf -or -not (Test-Path -LiteralPath $pf)) { continue }
        $hit = Get-ChildItem -LiteralPath $pf -Directory -Filter "LLVM*" -ErrorAction SilentlyContinue |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "bin\libclang.dll") } |
            Sort-Object Name -Descending |
            Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

if (-not $VcpkgRoot) { $VcpkgRoot = if ($env:VCPKG_ROOT) { $env:VCPKG_ROOT } else { "D:\iGame+\vcpkg" } }
if (-not $FlutterRoot) { $FlutterRoot = if ($env:FLUTTER_ROOT) { $env:FLUTTER_ROOT } else { "D:\iGame+\tools\flutter" } }

# vcvars 的 set 导出会覆盖整个会话环境，先保存 bindgen / vcpkg 相关变量
$saved = @{
    LIBCLANG_PATH = $env:LIBCLANG_PATH
    LLVM_HOME     = $env:LLVM_HOME
    VCPKG_ROOT    = $env:VCPKG_ROOT
    VCPKG_INSTALLED_ROOT = $env:VCPKG_INSTALLED_ROOT
    PATH          = $env:PATH
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (-not (Test-Path $vswhere)) { Write-Error "vswhere not found. Install VS Build Tools with C++ workload." }
$vsInstall = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
if ($vsInstall) { $vsInstall = $vsInstall.Trim() }
if (-not $vsInstall) {
    $vsInstall = (& $vswhere -latest -products * -prerelease -property installationPath | Select-Object -First 1)
    if ($vsInstall) { $vsInstall = $vsInstall.Trim() }
}
if (-not $vsInstall) {
    $fallback = Get-ChildItem -LiteralPath "${env:ProgramFiles(x86)}\Microsoft Visual Studio" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+$' } |
        Sort-Object { [int]$_.Name } -Descending |
        Select-Object -First 1
    if ($fallback) {
        $bt = Join-Path $fallback.FullName "BuildTools"
        $vsInstall = if (Test-Path -LiteralPath $bt) { $bt } else { $fallback.FullName }
    }
}
$vcvars64 = Join-Path $vsInstall "VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path -LiteralPath $vcvars64)) { Write-Error "vcvars64.bat not found under $vsInstall" }

$env:PATH = "$env:SystemRoot;$env:SystemRoot\System32"
$envDump = Join-Path $env:TEMP "rustdesk-vce-$([Guid]::NewGuid().ToString('n')).txt"
$batPath = Join-Path $env:TEMP "rustdesk-vcr-$([Guid]::NewGuid().ToString('n')).cmd"
try {
    [System.IO.File]::WriteAllText($batPath, "@echo off`r`ncall `"$vcvars64`"`r`nset > `"$envDump`"`r`n", [System.Text.Encoding]::Default)
    $null = & cmd.exe /d /s /c "`"$batPath`""
    if (-not (Test-Path -LiteralPath $envDump)) { Write-Error "MSVC env dump failed: $envDump" }
    Get-Content -LiteralPath $envDump -Encoding Default | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { Set-Item -LiteralPath ("Env:" + $Matches[1]) -Value $Matches[2] }
    }
} finally {
    Remove-Item $batPath, $envDump -Force -ErrorAction SilentlyContinue
}

# 恢复并优先使用用户/参数指定的 LLVM（bindgen 必需）
$llvmPrefer = if ($LlvmRoot) { $LlvmRoot } elseif ($saved.LLVM_HOME) { $saved.LLVM_HOME } elseif ($saved.LIBCLANG_PATH) { $saved.LIBCLANG_PATH } else { "" }
$resolvedLlvm = Find-LlvmRoot -Prefer $llvmPrefer
if (-not $resolvedLlvm) {
    Write-Error @"
libclang.dll not found. bindgen (scrap / magnum-opus) requires LLVM.

Install LLVM for Windows (64-bit) and either:
  1) Add to user env: LIBCLANG_PATH = C:\Path\To\LLVM\bin
  2) Re-run: . .\scripts\Enter-RustdeskBuildEnv.ps1 -LlvmRoot 'C:\Path\To\LLVM'

Verify: Test-Path 'C:\Path\To\LLVM\bin\libclang.dll'
"@
}
$env:LIBCLANG_PATH = Join-Path $resolvedLlvm "bin"
$env:LLVM_HOME = $resolvedLlvm
$env:PATH = "$env:LIBCLANG_PATH;$env:PATH"
Write-Host "LIBCLANG_PATH=$env:LIBCLANG_PATH"

if (Test-Path (Join-Path $FlutterRoot "bin\flutter.bat")) {
    $env:PATH = "$(Join-Path $FlutterRoot 'bin');$env:PATH"
    Write-Host "Flutter: $FlutterRoot"
}

$env:VCPKG_ROOT = if ($saved.VCPKG_ROOT) { $saved.VCPKG_ROOT } else { $VcpkgRoot }
$env:PATH = "$env:VCPKG_ROOT;$env:PATH"
$manifestInstalled = Join-Path $RepoRoot "vcpkg_installed"
if (Test-Path $manifestInstalled) {
    $env:VCPKG_INSTALLED_ROOT = $manifestInstalled
    Write-Host "VCPKG_INSTALLED_ROOT=$env:VCPKG_INSTALLED_ROOT"
}

$cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
if (Test-Path -LiteralPath $cargoBin) { $env:PATH = "$cargoBin;$env:PATH" }

Write-Host "VCPKG_ROOT=$env:VCPKG_ROOT"
Write-Host "Repo: $RepoRoot"
