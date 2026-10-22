<#
.SYNOPSIS
    Create a new C++ project from this template.

.DESCRIPTION
    A thin wrapper: the generator itself is new-project.cmake, the same one
    new-project.sh runs, so both produce the same project. Every argument is
    passed on unchanged; run with --help for the full list of options.

    Options can be written in the PowerShell style (-Std 20, -Lib, -NoGit,
    -GitHubUser <user>, -Author <name>) or in the bash style of
    new-project.sh (--std 20, --lib, --no-git, --github-user <user>,
    --author <name>).

    Needs CMake 3.25+. When cmake is not on PATH, the copy that comes with
    Visual Studio (the "C++ CMake tools for Windows" component) is used.
    Runs in Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
    .\scripts\new-project.ps1 bank_app

.EXAMPLE
    .\scripts\new-project.ps1 bank_app C:\dev\bank -Std 20 -Author "Jane Doe"

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\new-project.ps1 bank_lib --lib --no-git
#>

# No param() block on purpose: every argument, in either spelling, reaches
# $args unchanged and goes to new-project.cmake, which parses them.
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
$cmakeArgs = @('-P', (Join-Path $PSScriptRoot 'new-project.cmake'), '--') + @($args)
& $cmake @cmakeArgs
exit $LASTEXITCODE
