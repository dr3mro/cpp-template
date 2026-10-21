<#
.SYNOPSIS
    Create a new C++ project from this template (Windows version of new-project.sh).

.DESCRIPTION
    Copies the template, renames the "myapp" placeholder everywhere (CMake
    project, executable, namespace, include/<name>/ and src/<name>/ folders,
    option names, editor tasks, CI workflows, the Visual Studio solution and
    project), gives the Visual Studio project a fresh GUID, sets the C++
    standard, swaps in the project README and makes the first git commit.

    It produces the same project as scripts/new-project.sh, and runs in
    Windows PowerShell 5.1 and PowerShell 7 on Windows, macOS and Linux.
    Nothing else is needed: no bash, perl or Python.

.PARAMETER Name
    Project name: a lower_snake_case C++ identifier, for example inventory or
    bank_app. It becomes the CMake project, the executable, the namespace and
    the include/<name>/ folder.

.PARAMETER Destination
    Folder to create. Defaults to .\<Name> in the current folder.

.PARAMETER Std
    C++ standard: 17 (default), 20 or 23.

.PARAMETER Lib
    Generate an installable library package (with examples/) instead of an app.

.PARAMETER NoGit
    Do not initialise a git repository.

.PARAMETER GitHubUser
    Fill in the README's GitHub Pages docs link (https://<user>.github.io/<name>/).

.EXAMPLE
    .\scripts\new-project.ps1 bank_app

.EXAMPLE
    .\scripts\new-project.ps1 bank_app C:\dev\bank -Std 20 -GitHubUser dr3mro

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\new-project.ps1 bank_lib -Lib
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Name,

    [Parameter(Position = 1)]
    [string]$Destination,

    [ValidateSet('17', '20', '23')]
    [string]$Std = '17',

    [switch]$Lib,

    [switch]$NoGit,

    [string]$GitHubUser = ''
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    [Console]::Error.WriteLine("error: $Message")
    exit 1
}

# ---- validate the arguments ---------------------------------------------------

if ($Name -cnotmatch '^[a-z][a-z0-9_]*$') {
    Fail 'name must be lower_snake_case, e.g. bank_app'
}

# Names that would produce a project that does not build, or one that breaks
# the rules of C++: keywords, the reserved std/posix namespaces, targets that
# CMake or the template already define, the test framework, and folder names
# Windows does not allow. Keep this list in step with new-project.sh.
$reserved = @(
    # C++ keywords and alternative operator spellings
    'alignas', 'alignof', 'and', 'and_eq', 'asm', 'auto', 'bitand', 'bitor', 'bool', 'break',
    'case', 'catch', 'char', 'char8_t', 'char16_t', 'char32_t', 'class', 'compl', 'concept',
    'const', 'consteval', 'constexpr', 'constinit', 'const_cast', 'continue', 'co_await',
    'co_return', 'co_yield', 'decltype', 'default', 'delete', 'do', 'double', 'dynamic_cast',
    'else', 'enum', 'explicit', 'export', 'extern', 'false', 'float', 'for', 'friend', 'goto',
    'if', 'inline', 'int', 'long', 'mutable', 'namespace', 'new', 'noexcept', 'not', 'not_eq',
    'nullptr', 'operator', 'or', 'or_eq', 'private', 'protected', 'public', 'register',
    'reinterpret_cast', 'requires', 'return', 'short', 'signed', 'sizeof', 'static',
    'static_assert', 'static_cast', 'struct', 'switch', 'template', 'this', 'thread_local',
    'throw', 'true', 'try', 'typedef', 'typeid', 'typename', 'union', 'unsigned', 'using',
    'virtual', 'void', 'volatile', 'wchar_t', 'while', 'xor', 'xor_eq',
    # namespaces reserved by the standard
    'std', 'posix',
    # targets CMake defines
    'all', 'clean', 'help', 'install', 'install_local', 'install_strip', 'test', 'package',
    'package_source', 'edit_cache', 'rebuild_cache', 'list_install_components',
    # targets the template defines, and its test framework
    'docs', 'format', 'tidy', 'coverage', 'distclean', 'doctest',
    # the example program and the fuzzer of the template
    'example', 'fuzz_greeter',
    # names Windows does not allow for a file or folder
    'con', 'prn', 'aux', 'nul',
    'com1', 'com2', 'com3', 'com4', 'com5', 'com6', 'com7', 'com8', 'com9',
    'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5', 'lpt6', 'lpt7', 'lpt8', 'lpt9'
)
if ($reserved -ccontains $Name) {
    Fail "'$Name' cannot be a project name: it is a C++ keyword, a reserved namespace, a build target name or a reserved Windows name. Pick another, e.g. ${Name}_app"
}
# Identifiers with a double underscore are reserved for the implementation.
if ($Name.Contains('__') -or $Name.EndsWith('_')) {
    Fail 'name must not contain "__" or end with "_"'
}
if ($GitHubUser -and $GitHubUser -notmatch '^[A-Za-z0-9-]+$') {
    Fail '-GitHubUser must be a GitHub user name (letters, digits, -)'
}

$TemplateDir = Split-Path -Parent $PSScriptRoot
if (-not $Destination) {
    $Destination = Join-Path (Get-Location).Path $Name
}
# Resolve to a full path without requiring it to exist.
$Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
if (Test-Path -LiteralPath $Destination) {
    Fail "$Destination already exists"
}

$Upper = $Name.ToUpperInvariant()
# Latin-1 maps every byte to one character and back, so reading and writing
# with it changes only the placeholder and keeps the encoding, the BOM (if
# any) and the line endings of every file exactly as they were.
$Bytes = [System.Text.Encoding]::GetEncoding(28591)

function Edit-File([string]$Path, [scriptblock]$Change) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $old = [System.IO.File]::ReadAllText($Path, $Bytes)
    $new = & $Change $old
    if ($new -cne $old) {
        [System.IO.File]::WriteAllText($Path, $new, $Bytes)
    }
}

function Test-Command([string]$Command) {
    return [bool](Get-Command $Command -CommandType Application -ErrorAction SilentlyContinue)
}

# Run git without letting its stderr become a terminating error: Windows
# PowerShell 5.1 turns redirected native stderr into an ErrorRecord, which
# $ErrorActionPreference = 'Stop' would throw.
function Invoke-Git {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & git @args 2>$null } finally { $ErrorActionPreference = $saved }
}

Write-Host "Creating $Name in $Destination (C++$Std)"

# ---- copy the template ----------------------------------------------------------
# Copy only files git tracks (plus new files that are not ignored), so build
# output and other ignored clutter never leak into the new project. Without git
# (a zip download), copy everything except the same kinds of paths.

$files = @()
$useGit = $false
if (Test-Command 'git') {
    $inside = Invoke-Git -C $TemplateDir rev-parse --is-inside-work-tree
    if ($LASTEXITCODE -eq 0 -and $inside -eq 'true') { $useGit = $true }
}
if ($useGit) {
    # -z: NUL-separated, so names with spaces or non-ASCII characters survive.
    $raw = (Invoke-Git -C $TemplateDir -c core.quotepath=off ls-files -z --cached --others --exclude-standard) -join "`n"
    if ($LASTEXITCODE -ne 0) { Fail 'git ls-files failed in the template folder' }
    $files = $raw -split "`0" | Where-Object { $_ } | Sort-Object -Unique |
        Where-Object { Test-Path -LiteralPath (Join-Path $TemplateDir $_) -PathType Leaf }
} else {
    $excludeTop = @('.git', 'build', 'docs', 'install', 'vcpkg_installed', '.cache', 'wiki')
    $root = (Resolve-Path -LiteralPath $TemplateDir).Path.TrimEnd('\', '/')
    $files = Get-ChildItem -LiteralPath $root -Recurse -Force -File | ForEach-Object {
        $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    } | Where-Object {
        $top = ($_ -split '/')[0]
        -not ($excludeTop -contains $top -or $top -like 'install-*' -or
              $_ -like '*.DS_Store' -or $_ -eq '.gitmodules')
    }
}

New-Item -ItemType Directory -Path $Destination -Force | Out-Null
foreach ($rel in $files) {
    $source = Join-Path $TemplateDir $rel
    $target = Join-Path $Destination $rel
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Copy-Item -LiteralPath $source -Destination $target -Force
}

# Template-only files: the generator scripts, the template's own test workflow,
# and the wiki (it describes the template, not the new project).
foreach ($rel in @('scripts/new-project.sh', 'scripts/new-project.ps1',
                   'scripts/edit-json.pl',
                   '.github/workflows/template-test.yml', '.github/workflows/wiki.yml',
                   '.gitmodules', 'wiki')) {
    $path = Join-Path $Destination $rel
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
}
$scripts = Join-Path $Destination 'scripts'
if ((Test-Path -LiteralPath $scripts) -and -not (Get-ChildItem -LiteralPath $scripts -Force)) {
    Remove-Item -LiteralPath $scripts -Force
}

# ---- rename paths that carry the placeholder ------------------------------------
# Deepest paths first, so a folder is renamed after everything inside it.
Get-ChildItem -LiteralPath $Destination -Recurse -Force |
    Where-Object { $_.Name -cmatch 'myapp|MYAPP' } |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
        $newName = $_.Name.Replace('MYAPP', $Upper).Replace('myapp', $Name)
        Rename-Item -LiteralPath $_.FullName -NewName $newName
    }

# ---- Visual Studio project GUID ---------------------------------------------------
# Every project gets its own GUID (the template ships a placeholder). This runs
# before the placeholder replacement, so the GUID is not touched by it.
$guid = [guid]::NewGuid().ToString().ToUpperInvariant()
foreach ($vsFile in @("$Name.sln", "$Name.vcxproj")) {
    Edit-File (Join-Path $Destination $vsFile) {
        param($text) $text.Replace('3F2A6B1C-9D4E-4C7A-8B5F-1E2D3C4B5A69', $guid)
    }
}

# ---- replace the placeholder in every file -----------------------------------------
Get-ChildItem -LiteralPath $Destination -Recurse -Force -File |
    Where-Object { $_.Extension -ne '.png' } |
    ForEach-Object {
        Edit-File $_.FullName { param($text) $text.Replace('MYAPP', $Upper).Replace('myapp', $Name) }
    }

# vcpkg package names allow hyphens but not underscores. The manifest's
# "version" stays the single source of truth for the project version.
$vcpkgName = $Name.Replace('_', '-')
Edit-File (Join-Path $Destination 'vcpkg.json') {
    param($text) [regex]::Replace($text, '"name": "[^"]+"', "`"name`": `"$vcpkgName`"")
}

# ---- C++ standard ----------------------------------------------------------------------
Edit-File (Join-Path $Destination 'src/CMakeLists.txt') {
    param($text) $text.Replace('cxx_std_17', "cxx_std_$Std")
}
Edit-File (Join-Path $Destination '.clang-format') {
    param($text) [regex]::Replace($text, '(?m)^Standard: c\+\+17', "Standard: c++$Std")
}
# Visual Studio 2019 and 2022 have no "stdcpp23", so C++23 maps to the latest.
$vsStd = @{ '17' = 'stdcpp17'; '20' = 'stdcpp20'; '23' = 'stdcpplatest' }[$Std]
Edit-File (Join-Path $Destination "$Name.vcxproj") {
    param($text) $text.Replace('stdcpp17', $vsStd)
}

# ---- README -------------------------------------------------------------------------------
$readme = Join-Path $Destination 'README.md'
Remove-Item -LiteralPath $readme -Force -ErrorAction SilentlyContinue
Move-Item -LiteralPath (Join-Path $Destination 'PROJECT_README.md') -Destination $readme
$ghText = if ($GitHubUser) { $GitHubUser } else { 'your-github-user' }
Edit-File $readme { param($text) $text.Replace('@GITHUB_USER@', $ghText) }

# ---- app or library -------------------------------------------------------------------------
# JSON written the way Python's json.dumps(indent=2) writes it, so this script
# and new-project.sh produce byte-identical editor files.
function ConvertTo-PyJson($Value, [int]$Level = 0) {
    $pad = '  ' * ($Level + 1)
    $end = '  ' * $Level
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [string] -or $Value -is [datetime]) {
        $s = if ($Value -is [datetime]) { $Value.ToString('o') } else { $Value }
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('"')
        foreach ($c in $s.ToCharArray()) {
            switch ([int]$c) {
                0x22 { [void]$sb.Append('\"') }
                0x5C { [void]$sb.Append('\\') }
                0x0A { [void]$sb.Append('\n') }
                0x0D { [void]$sb.Append('\r') }
                0x09 { [void]$sb.Append('\t') }
                0x08 { [void]$sb.Append('\b') }
                0x0C { [void]$sb.Append('\f') }
                default {
                    if ([int]$c -lt 0x20 -or [int]$c -gt 0x7E) { [void]$sb.AppendFormat('\u{0:x4}', [int]$c) }
                    else { [void]$sb.Append($c) }
                }
            }
        }
        [void]$sb.Append('"')
        return $sb.ToString()
    }
    if ($Value -is [System.Collections.IDictionary] -or $Value -is [System.Management.Automation.PSCustomObject]) {
        # A typed list, so a one-key object is not unrolled by the pipeline.
        $pairs = New-Object 'System.Collections.Generic.List[object[]]'
        if ($Value -is [System.Collections.IDictionary]) {
            foreach ($k in $Value.Keys) { $pairs.Add(@([string]$k, $Value[$k])) }
        } else {
            foreach ($prop in $Value.PSObject.Properties) { $pairs.Add(@($prop.Name, $prop.Value)) }
        }
        if ($pairs.Count -eq 0) { return '{}' }
        $items = foreach ($p in $pairs) { $pad + (ConvertTo-PyJson $p[0]) + ': ' + (ConvertTo-PyJson -Value $p[1] -Level ($Level + 1)) }
        return "{`n" + ($items -join ",`n") + "`n$end}"
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $list = @($Value)
        if ($list.Count -eq 0) { return '[]' }
        $items = foreach ($v in $list) { $pad + (ConvertTo-PyJson -Value $v -Level ($Level + 1)) }
        return "[`n" + ($items -join ",`n") + "`n$end]"
    }
    if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        return ([double]$Value).ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    return ([string]$Value)
}

function Remove-JsonEntries([string]$Path, [string]$ListKey, [string]$Key, [string[]]$Unwanted) {
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    # -InputObject, not the pipeline: Windows PowerShell 5.1 and PowerShell 7
    # then both hand back the top-level array the same way.
    $parsed = ConvertFrom-Json -InputObject $text
    if ($ListKey) {
        $parsed.$ListKey = @(@($parsed.$ListKey) | Where-Object { $Unwanted -notcontains $_.$Key })
        $json = ConvertTo-PyJson $parsed
    } else {
        $kept = @(@($parsed) | Where-Object { $Unwanted -notcontains $_.$Key })
        $json = ConvertTo-PyJson -Value $kept
    }
    [System.IO.File]::WriteAllText($Path, $json + "`n", (New-Object System.Text.UTF8Encoding $false))
}

$workflows = Join-Path $Destination '.github/workflows'
if ($Lib) {
    Edit-File (Join-Path $Destination 'cmake/Options.cmake') {
        param($text) [regex]::Replace($text, '(option\(\w+_LIBRARY_MODE\s+"[^"]*"\s+)OFF\b', '${1}ON')
    }
    Remove-Item -LiteralPath (Join-Path $Destination 'main.cpp') -Force -ErrorAction SilentlyContinue

    # A library has no executable: drop the run tasks and the app debug
    # configuration. Zed's tasks.json keeps one object per line.
    $zedTasks = Join-Path $Destination '.zed/tasks.json'
    if (Test-Path -LiteralPath $zedTasks) {
        $lines = [System.IO.File]::ReadAllText($zedTasks, $Bytes) -split "`r?`n"
        if ($lines[-1] -eq '') { $lines = $lines[0..($lines.Count - 2)] }
        $kept = $lines | Where-Object { $_ -notmatch '"label": "run"' -and $_ -notmatch '"label": "run debug"' }
        [System.IO.File]::WriteAllText($zedTasks, (($kept -join "`n") + "`n"), $Bytes)
    }
    Remove-JsonEntries (Join-Path $Destination '.zed/debug.json') '' 'label' @("Debug $Name")
    Remove-JsonEntries (Join-Path $Destination '.vscode/tasks.json') 'tasks' 'label' @('run')
    Remove-JsonEntries (Join-Path $Destination '.vscode/launch.json') 'configurations' 'name' @("Debug $Name")

    Remove-Item -LiteralPath (Join-Path $workflows 'release-app.yml') -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath (Join-Path $workflows 'release-lib.yml') -Destination (Join-Path $workflows 'release.yml')
} else {
    Remove-Item -LiteralPath (Join-Path $Destination 'examples') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $workflows 'release-lib.yml') -Force -ErrorAction SilentlyContinue
    Move-Item -LiteralPath (Join-Path $workflows 'release-app.yml') -Destination (Join-Path $workflows 'release.yml')
}

# ---- git ------------------------------------------------------------------------------------
if (-not $NoGit -and (Test-Command 'git')) {
    Push-Location -LiteralPath $Destination
    try {
        Invoke-Git init -q -b main | Out-Null
        Invoke-Git add -A | Out-Null
        Invoke-Git commit -qm 'Initial commit from C++ template' | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host 'Initialised git repository on branch main' }
        else { Write-Warning 'git commit failed; set user.name and user.email, then commit yourself.' }
    } finally {
        Pop-Location
    }
}

# ---- next steps -----------------------------------------------------------------------------
$vcpkgReady = $env:VCPKG_ROOT -and
    (Test-Path -LiteralPath (Join-Path $env:VCPKG_ROOT 'scripts/buildsystems/vcpkg.cmake'))
$onWindows = [System.IO.Path]::DirectorySeparatorChar -eq '\'

Write-Host ''
Write-Host 'Done. Next steps:'
Write-Host "  cd `"$Destination`""
if ($onWindows) {
    Write-Host "  start $Name.sln                 # Visual Studio 2019, 2022 or 2026, no CMake needed"
    Write-Host ''
    Write-Host '  or with CMake, from a "Developer PowerShell for VS":'
    Write-Host '  cmake --preset release; cmake --build --preset release; ctest --preset release'
} else {
    Write-Host '  cmake --preset debug && cmake --build --preset debug && ctest --preset debug'
}
if ($Lib) {
    Write-Host '  cmake --install build/release'
    Write-Host '  cmake -S examples -B build/examples -DCMAKE_PREFIX_PATH="$PWD/build/install/release"; cmake --build build/examples'
}

if (-not $vcpkgReady) {
    Write-Host ''
    Write-Host 'vcpkg is not set up yet (VCPKG_ROOT missing or invalid), so a CMake build'
    Write-Host 'will fail. The Visual Studio solution does not need it. One-time setup'
    Write-Host '(a full clone: vcpkg.json pins a baseline commit, so no --depth 1):'
    Write-Host ''
    if ($onWindows) {
        Write-Host '  git clone https://github.com/microsoft/vcpkg.git C:\vcpkg'
        Write-Host '  C:\vcpkg\bootstrap-vcpkg.bat -disableMetrics'
        Write-Host '  [Environment]::SetEnvironmentVariable("VCPKG_ROOT", "C:\vcpkg", "User")'
        Write-Host ''
        Write-Host 'Then open a new terminal (and restart Visual Studio).'
    } else {
        Write-Host '  git clone https://github.com/microsoft/vcpkg.git ~/.vcpkg'
        Write-Host '  ~/.vcpkg/bootstrap-vcpkg.sh -disableMetrics'
        Write-Host '  export VCPKG_ROOT="$HOME/.vcpkg"     # add this line to your shell profile'
    }
    Write-Host ''
    Write-Host 'See README.md for details.'
}
