<#
.SYNOPSIS
    Build, test, run and check the project.

.DESCRIPTION
    A thin wrapper: the implementation is cmake/cx/cx.cmake, the same one cx
    and cx.cmd run, so every platform has the same commands. This script only
    finds cmake and starts it from the project root.

    Run with "help" for the list of commands, or with "help <command>" for one
    command's usage. Presets are plain words: .\cx.ps1 build release,
    .\cx.ps1 test nosan, .\cx.ps1 run -- Amr.

    Needs CMake 3.25+. When cmake is not on PATH, the copy that comes with
    Visual Studio (the "C++ CMake tools for Windows" component) is used.
    Runs in Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
    .\cx.ps1 test

.EXAMPLE
    .\cx.ps1 run release -- Amr

.EXAMPLE
    .\cx.ps1 dev --run
#>

# No param() block on purpose: every argument reaches $args unchanged and goes
# to cx.cmake, which parses it.
$ErrorActionPreference = 'Stop'

$cmake = Get-Command cmake -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Source

if (-not $cmake) {
    # Visual Studio ships CMake, but only puts it on PATH inside a developer
    # shell. Ask the Visual Studio Installer where Visual Studio is.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (${env:ProgramFiles(x86)} -and (Test-Path -LiteralPath $vswhere)) {
        $vs = & $vswhere -latest -products * -property installationPath | Select-Object -First 1
        if ($vs) {
            $candidate = Join-Path $vs 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
            if (Test-Path -LiteralPath $candidate) { $cmake = $candidate }
        }
    }
}

if (-not $cmake) {
    [Console]::Error.WriteLine('error: cmake was not found. Install CMake 3.25+ (winget install Kitware.CMake),')
    [Console]::Error.WriteLine('or the "C++ CMake tools for Windows" component of Visual Studio.')
    exit 1
}

# The "--" goes in through an array: written on the command line, Windows
# PowerShell 5.1 can swallow it as its own end-of-parameters marker.
$cmakeArgs = @('-P', (Join-Path $PSScriptRoot 'cmake/cx/cx.cmake'), '--') + @($args)
Set-Location -LiteralPath $PSScriptRoot
& $cmake @cmakeArgs
exit $LASTEXITCODE
