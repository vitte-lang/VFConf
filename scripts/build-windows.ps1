#Requires -Version 7.0
<#
.SYNOPSIS
    VFConf Windows build and packaging script.

.DESCRIPTION
    Builds, validates, tests and packages VFConf for Windows.

    Produces all VFConf command-line executables:
      vfconf.exe
      vfconf-check.exe
      vfconf-dump.exe
      vfconf-fmt.exe
      vfconf-fmt-all.exe
      vfconf-get.exe
      vfconf-set.exe
      vfconf-unset.exe
      vfconf-exists.exe
      vfconf-list.exe
      vfconf-tree.exe
      vfconf-diff.exe
      vfconf-merge.exe
      vfconf-resolve.exe
      vfconf-eval.exe
      vfconf-query.exe
      vfconf-diagnostics.exe
      vfconf-explain.exe
      vfconf-stats.exe
      vfconf-check-all.exe

    Supported Windows architectures depend on the installed
    OCaml/Dune toolchain.

.NOTES
    Project:
      VFConf — Vitte Foundation Configuration Language

    Script:
      scripts/build-windows.ps1
#>

[CmdletBinding()]
param(
    [ValidateSet("dev", "release")]
    [string]$Profile = "release",

    [switch]$Clean,

    [switch]$Test,

    [switch]$NoDiagnostics,

    [switch]$Docs,

    [switch]$NoPackage,

    [switch]$NoArchive,

    [switch]$NoChecksum,

    [ValidateRange(1, 1024)]
    [int]$Jobs = 0,

    [switch]$VerboseBuild
)

Set-StrictMode -Version Latest

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$ProjectRoot = (
    Resolve-Path (
        Join-Path $ScriptDir ".."
    )
).Path

$DistDir = Join-Path $ProjectRoot "dist"

$ProjectName = "vfconf"

$RunDiagnostics = -not $NoDiagnostics
$Package = -not $NoPackage
$CreateArchive = -not $NoArchive
$Checksums = -not $NoChecksum

$VFConfExecutables = [ordered]@{
    "main"        = "vfconf"
    "check"       = "vfconf-check"
    "dump"        = "vfconf-dump"
    "fmt"         = "vfconf-fmt"
    "fmt_all"     = "vfconf-fmt-all"
    "get"         = "vfconf-get"
    "set_cmd"     = "vfconf-set"
    "unset"       = "vfconf-unset"
    "exists"      = "vfconf-exists"
    "list_cmd"    = "vfconf-list"
    "tree_cmd"    = "vfconf-tree"
    "diff_cmd"    = "vfconf-diff"
    "merge_cmd"   = "vfconf-merge"
    "resolve_cmd" = "vfconf-resolve"
    "eval_cmd"    = "vfconf-eval"
    "query_cmd"   = "vfconf-query"
    "diagnostics" = "vfconf-diagnostics"
    "explain"     = "vfconf-explain"
    "stats"       = "vfconf-stats"
    "check_all"   = "vfconf-check-all"
}

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[vfconf-windows] $Message"
}

function Write-WarningMessage {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Warning "[vfconf-windows] $Message"
}

function Fail {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    throw "[vfconf-windows] $Message"
}

function Test-Command {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    return $null -ne (
        Get-Command $Name -ErrorAction SilentlyContinue
    )
}

function Require-Command {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not (Test-Command $Name)) {
        Fail "Required command not found: $Name"
    }
}

function Get-ProjectVersion {
    $versionFile = Join-Path $ProjectRoot "VERSION"

    if (Test-Path $versionFile -PathType Leaf) {
        $version = (
            Get-Content $versionFile -Raw
        ).Trim()

        if ($version) {
            return $version
        }
    }

    $duneProject = Join-Path $ProjectRoot "dune-project"

    if (Test-Path $duneProject -PathType Leaf) {
        foreach ($line in Get-Content $duneProject) {
            if ($line -match '^\s*\(version\s+([^)]+)\)') {
                return $Matches[1].Trim()
            }
        }
    }

    Fail "Unable to determine VFConf version"
}

function Get-WindowsArchitecture {
    $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture

    switch ($architecture) {
        "X64" {
            return "x86_64"
        }

        "X86" {
            return "x86"
        }

        "Arm64" {
            return "arm64"
        }

        "Arm" {
            return "arm"
        }

        default {
            return $architecture.ToString().ToLowerInvariant()
        }
    }
}

function Get-PlatformName {
    return "windows-$(Get-WindowsArchitecture)"
}

function Test-Project {
    $required = @(
        "dune-project",
        "lib/dune",
        "bin/dune"
    )

    foreach ($relative in $required) {
        $path = Join-Path $ProjectRoot $relative

        if (-not (Test-Path $path -PathType Leaf)) {
            Fail "Required project file not found: $relative"
        }
    }

    $null = Get-ProjectVersion
}

function Test-Tools {
    Require-Command "dune"
    Require-Command "ocamlc"
    Require-Command "ocamllex"
    Require-Command "menhir"

    $ocamlVersion = (& ocamlc -version).Trim()
    $duneVersion = (& dune --version).Trim()

    $menhirVersion = "available"

    try {
        $value = (& menhir --version 2>$null)

        if ($value) {
            $menhirVersion = (
                $value |
                Out-String
            ).Trim()
        }
    }
    catch {
        $menhirVersion = "available"
    }

    Write-Log "OCaml:  $ocamlVersion"
    Write-Log "Dune:   $duneVersion"
    Write-Log "Menhir: $menhirVersion"

    if (Test-Command "ocamlopt") {
        Write-Log "Native compiler: available"
    }
    else {
        Write-WarningMessage "ocamlopt unavailable; native compilation may fail"
    }

    if ($RunDiagnostics) {
        $audit = Join-Path $ProjectRoot "scripts/audit-diagnostics.py"

        if (Test-Path $audit -PathType Leaf) {
            Require-Command "python"
        }
    }
}

function Invoke-Dune {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $common = @(
        "--profile=$Profile"
    )

    if ($Jobs -gt 0) {
        $common += "-j"
        $common += $Jobs.ToString()
    }

    if ($VerboseBuild) {
        $common += "--display=verbose"
    }
    else {
        $common += "--display=short"
    }

    & dune @Arguments @common

    if ($LASTEXITCODE -ne 0) {
        Fail "Dune command failed with exit code $LASTEXITCODE"
    }
}

function Clean-Project {
    if (-not $Clean) {
        return
    }

    Write-Log "Cleaning previous build"

    & dune clean

    if ($LASTEXITCODE -ne 0) {
        Fail "dune clean failed"
    }
}

function Build-Project {
    Write-Log "Building VFConf"
    Write-Log "Profile: $Profile"
    Write-Log "Executables: $($VFConfExecutables.Count)"

    $targets = @()

    foreach ($buildName in $VFConfExecutables.Keys) {
        $targets += "bin/$buildName.exe"
    }

    Invoke-Dune (
        @("build") + $targets
    )

    Write-Log "Compilation completed"
}

function Find-BuiltBinary {
    param(
        [Parameter(Mandatory)]
        [string]$BuildName
    )

    $primary = Join-Path `
        $ProjectRoot `
        "_build/default/bin/$BuildName.exe"

    if (Test-Path $primary -PathType Leaf) {
        return (Resolve-Path $primary).Path
    }

    $buildDirectory = Join-Path $ProjectRoot "_build"

    if (-not (Test-Path $buildDirectory -PathType Container)) {
        return $null
    }

    $candidate = Get-ChildItem `
        -Path $buildDirectory `
        -Filter "$BuildName.exe" `
        -File `
        -Recurse `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -match '[\\/]bin[\\/]'
        } |
        Select-Object -First 1

    if ($candidate) {
        return $candidate.FullName
    }

    return $null
}

function Verify-BuildOutputs {
    Write-Log "Verifying compiled executables"

    $verified = 0

    foreach ($buildName in $VFConfExecutables.Keys) {
        $publicName = $VFConfExecutables[$buildName]

        $binary = Find-BuiltBinary $buildName

        if (-not $binary) {
            Fail "Compiled executable unavailable: $buildName.exe ($publicName.exe)"
        }

        $item = Get-Item $binary

        if ($item.Length -le 0) {
            Fail "Compiled executable is empty: $binary"
        }

        if ($VerboseBuild) {
            Write-Host (
                "  {0,-24} {1}" -f `
                "$publicName.exe", `
                $binary
            )
        }

        $verified++
    }

    if ($verified -ne $VFConfExecutables.Count) {
        Fail "Executable verification count mismatch"
    }

    Write-Log "Verified $verified executables"
}

function Run-Tests {
    if (-not $Test) {
        return
    }

    Write-Log "Running Dune tests"

    Invoke-Dune @(
        "runtest"
    )

    Write-Log "Tests completed"
}

function Run-Diagnostics {
    if (-not $RunDiagnostics) {
        Write-WarningMessage "Diagnostics gate skipped"
        return
    }

    Write-Log "Running diagnostics gate"

    $powerShellGate = Join-Path `
        $ProjectRoot `
        "scripts/check-diagnostics.ps1"

    $shellGate = Join-Path `
        $ProjectRoot `
        "scripts/check-diagnostics.sh"

    $audit = Join-Path `
        $ProjectRoot `
        "scripts/audit-diagnostics.py"

    if (Test-Path $powerShellGate -PathType Leaf) {
        & $powerShellGate

        if ($LASTEXITCODE -ne 0) {
            Fail "Diagnostics gate failed"
        }

        Write-Log "Diagnostics gate passed"
        return
    }

    if (
        (Test-Path $shellGate -PathType Leaf) -and
        (Test-Command "bash")
    ) {
        & bash $shellGate

        if ($LASTEXITCODE -ne 0) {
            Fail "Diagnostics gate failed"
        }

        Write-Log "Diagnostics gate passed"
        return
    }

    if (Test-Path $audit -PathType Leaf) {
        Write-WarningMessage "Full diagnostics gate unavailable; running static audit"

        if (Test-Command "python") {
            & python $audit
        }
        elseif (Test-Command "python3") {
            & python3 $audit
        }
        else {
            Fail "Python is required for diagnostics audit"
        }

        if ($LASTEXITCODE -ne 0) {
            Fail "Static diagnostics audit failed"
        }

        Write-Log "Static diagnostics audit passed"
        return
    }

    Fail "Diagnostics requested but no diagnostics gate is available"
}

function Build-Documentation {
    if (-not $Docs) {
        return
    }

    Write-Log "Building documentation"

    Invoke-Dune @(
        "build",
        "@doc"
    )

    Write-Log "Documentation completed"
}

function Copy-Binary {
    param(
        [Parameter(Mandatory)]
        [string]$BuildName,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $source = Find-BuiltBinary $BuildName

    if (-not $source) {
        Fail "Cannot locate $BuildName.exe"
    }

    Copy-Item `
        -LiteralPath $source `
        -Destination $Destination `
        -Force
}

function Install-AllExecutables {
    param(
        [Parameter(Mandatory)]
        [string]$Destination
    )

    New-Item `
        -ItemType Directory `
        -Path $Destination `
        -Force |
        Out-Null

    foreach ($buildName in $VFConfExecutables.Keys) {
        $publicName = $VFConfExecutables[$buildName]

        Copy-Binary `
            -BuildName $buildName `
            -Destination (
                Join-Path `
                    $Destination `
                    "$publicName.exe"
            )
    }
}

function Copy-RuntimeData {
    param(
        [Parameter(Mandatory)]
        [string]$Destination
    )

    $directories = @(
        "config",
        "languages",
        "themes",
        "schemas",
        "examples"
    )

    foreach ($directory in $directories) {
        $source = Join-Path $ProjectRoot $directory

        if (Test-Path $source -PathType Container) {
            Copy-Item `
                -LiteralPath $source `
                -Destination (
                    Join-Path $Destination $directory
                ) `
                -Recurse `
                -Force
        }
    }
}

function Copy-Documentation {
    param(
        [Parameter(Mandatory)]
        [string]$Destination
    )

    $files = @(
        "README.md",
        "CHANGELOG.md",
        "LICENSE",
        "VERSION"
    )

    foreach ($file in $files) {
        $source = Join-Path $ProjectRoot $file

        if (Test-Path $source -PathType Leaf) {
            Copy-Item `
                -LiteralPath $source `
                -Destination $Destination `
                -Force
        }
    }

    $docs = Join-Path $ProjectRoot "docs"

    if (Test-Path $docs -PathType Container) {
        Copy-Item `
            -LiteralPath $docs `
            -Destination (
                Join-Path $Destination "docs"
            ) `
            -Recurse `
            -Force
    }
}

function Get-GitMetadata {
    $result = [ordered]@{
        Commit = "unknown"
        Dirty  = "unknown"
    }

    if (-not (Test-Command "git")) {
        return $result
    }

    try {
        & git `
            -C $ProjectRoot `
            rev-parse `
            --is-inside-work-tree `
            *> $null

        if ($LASTEXITCODE -ne 0) {
            return $result
        }

        $result.Commit = (
            & git `
                -C $ProjectRoot `
                rev-parse HEAD
        ).Trim()

        & git `
            -C $ProjectRoot `
            diff `
            --quiet `
            --ignore-submodules `
            HEAD `
            --

        if ($LASTEXITCODE -eq 0) {
            $result.Dirty = "false"
        }
        else {
            $result.Dirty = "true"
        }
    }
    catch {
        return $result
    }

    return $result
}

function Write-BuildMetadata {
    param(
        [Parameter(Mandatory)]
        [string]$Destination
    )

    $git = Get-GitMetadata

    $ocamlVersion = (& ocamlc -version).Trim()
    $duneVersion = (& dune --version).Trim()

    $content = @(
        "project=$ProjectName",
        "version=$(Get-ProjectVersion)",
        "profile=$Profile",
        "os=windows",
        "architecture=$(Get-WindowsArchitecture)",
        "platform=$(Get-PlatformName)",
        "ocaml=$ocamlVersion",
        "dune=$duneVersion",
        "executables=$($VFConfExecutables.Count)",
        "git_commit=$($git.Commit)",
        "git_dirty=$($git.Dirty)"
    )

    $path = Join-Path $Destination "BUILD-INFO"

    [System.IO.File]::WriteAllLines(
        $path,
        $content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Get-Sha256 {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return (
        Get-FileHash `
            -LiteralPath $Path `
            -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Create-BinaryManifest {
    param(
        [Parameter(Mandatory)]
        [string]$Destination
    )

    if (-not $Checksums) {
        return
    }

    $bin = Join-Path $Destination "bin"
    $manifest = Join-Path $Destination "SHA256SUMS"

    $lines = @()

    $files = Get-ChildItem `
        -LiteralPath $bin `
        -File |
        Sort-Object Name

    foreach ($file in $files) {
        $hash = Get-Sha256 $file.FullName

        $lines += "$hash  bin/$($file.Name)"
    }

    [System.IO.File]::WriteAllLines(
        $manifest,
        $lines,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Write-ArchiveChecksum {
    param(
        [Parameter(Mandatory)]
        [string]$Archive
    )

    if (-not $Checksums) {
        return
    }

    $hash = Get-Sha256 $Archive

    $checksumFile = "$Archive.sha256"
    $archiveName = Split-Path $Archive -Leaf

    [System.IO.File]::WriteAllText(
        $checksumFile,
        "$hash  $archiveName`n",
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Create-Archive {
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )

    if (-not $CreateArchive) {
        return
    }

    $parent = Split-Path $Directory -Parent
    $name = Split-Path $Directory -Leaf
    $archive = Join-Path $parent "$name.zip"

    Write-Log "Creating ZIP archive"

    if (Test-Path $archive) {
        Remove-Item `
            -LiteralPath $archive `
            -Force
    }

    Compress-Archive `
        -LiteralPath $Directory `
        -DestinationPath $archive `
        -CompressionLevel Optimal

    if (
        -not (Test-Path $archive -PathType Leaf) -or
        (Get-Item $archive).Length -le 0
    ) {
        Fail "Archive creation failed: $archive"
    }

    Write-ArchiveChecksum $archive

    Write-Log "Archive: $archive"
}

function Test-PackagedExecutables {
    param(
        [Parameter(Mandatory)]
        [string]$Destination
    )

    Write-Log "Verifying packaged executables"

    $bin = Join-Path $Destination "bin"
    $count = 0

    foreach ($publicName in $VFConfExecutables.Values) {
        $path = Join-Path $bin "$publicName.exe"

        if (-not (Test-Path $path -PathType Leaf)) {
            Fail "Packaged executable missing: $publicName.exe"
        }

        if ((Get-Item $path).Length -le 0) {
            Fail "Packaged executable is empty: $publicName.exe"
        }

        $count++
    }

    if ($count -ne $VFConfExecutables.Count) {
        Fail "Packaged executable count mismatch"
    }

    Write-Log "Verified $count packaged executables"
}

function Invoke-SmokeTest {
    param(
        [Parameter(Mandatory)]
        [string]$Destination
    )

    $main = Join-Path `
        $Destination `
        "bin/vfconf.exe"

    $checker = Join-Path `
        $Destination `
        "bin/vfconf-check.exe"

    Write-Log "Running Windows CLI smoke tests"

    if (Test-Path $main -PathType Leaf) {
        & $main --help *> $null

        if ($LASTEXITCODE -ne 0) {
            Fail "Packaged vfconf.exe --help failed"
        }
    }

    if (Test-Path $checker -PathType Leaf) {
        $temporary = Join-Path `
            ([System.IO.Path]::GetTempPath()) `
            "vfconf-$([guid]::NewGuid().ToString('N')).vf.conf"

        try {
            [System.IO.File]::WriteAllText(
                $temporary,
                "[test]`nname = `"vfconf`"`nenabled = true`n",
                [System.Text.UTF8Encoding]::new($false)
            )

            & $checker $temporary *> $null

            if ($LASTEXITCODE -ne 0) {
                Fail "Packaged vfconf-check.exe smoke test failed"
            }
        }
        finally {
            if (Test-Path $temporary) {
                Remove-Item `
                    -LiteralPath $temporary `
                    -Force
            }
        }
    }

    Write-Log "CLI smoke tests passed"
}

function Export-Distribution {
    if (-not $Package) {
        Write-Log "Packaging disabled"
        return
    }

    $version = Get-ProjectVersion
    $platform = Get-PlatformName

    $destination = Join-Path `
        $DistDir `
        "$ProjectName-$version-$platform"

    Write-Log "Creating Windows distribution"
    Write-Log "Platform: $platform"
    Write-Log "Destination: $destination"

    if (Test-Path $destination) {
        Remove-Item `
            -LiteralPath $destination `
            -Recurse `
            -Force
    }

    New-Item `
        -ItemType Directory `
        -Path $destination `
        -Force |
        Out-Null

    $bin = Join-Path $destination "bin"

    Install-AllExecutables $bin

    Copy-RuntimeData $destination
    Copy-Documentation $destination
    Write-BuildMetadata $destination
    Create-BinaryManifest $destination

    Test-PackagedExecutables $destination
    Invoke-SmokeTest $destination

    Create-Archive $destination

    Write-Log "Windows distribution created"
}

function Print-Summary {
    $version = Get-ProjectVersion
    $platform = Get-PlatformName

    Write-Host ""
    Write-Log "Build successful"

    Write-Host (
        "  version:       {0}" -f $version
    )

    Write-Host (
        "  OS:            Windows"
    )

    Write-Host (
        "  architecture:  {0}" -f (
            Get-WindowsArchitecture
        )
    )

    Write-Host (
        "  platform:      {0}" -f $platform
    )

    Write-Host (
        "  profile:       {0}" -f $Profile
    )

    Write-Host (
        "  executables:   {0}" -f $VFConfExecutables.Count
    )

    if ($Test) {
        Write-Host "  tests:         passed"
    }
    else {
        Write-Host "  tests:         not requested"
    }

    if ($RunDiagnostics) {
        Write-Host "  diagnostics:   passed"
    }
    else {
        Write-Host "  diagnostics:   skipped"
    }

    if ($Package) {
        Write-Host (
            "  distribution: dist/{0}-{1}-{2}" -f `
                $ProjectName, `
                $version, `
                $platform
        )

        if ($CreateArchive) {
            Write-Host (
                "  archive:      dist/{0}-{1}-{2}.zip" -f `
                    $ProjectName, `
                    $version, `
                    $platform
            )
        }
    }
    else {
        Write-Host "  distribution: disabled"
    }
}

function Main {
    Push-Location $ProjectRoot

    try {
        Test-Project
        Test-Tools

        if (-not (Test-Path $DistDir)) {
            New-Item `
                -ItemType Directory `
                -Path $DistDir `
                -Force |
                Out-Null
        }

        Write-Log "Project root: $ProjectRoot"
        Write-Log "Platform: $(Get-PlatformName)"
        Write-Log "Profile: $Profile"
        Write-Log "Executables: $($VFConfExecutables.Count)"

        Clean-Project
        Build-Project
        Verify-BuildOutputs

        Run-Tests
        Run-Diagnostics
        Build-Documentation

        Export-Distribution
        Print-Summary
    }
    finally {
        Pop-Location
    }
}

try {
    Main
}
catch {
    Write-Error "[vfconf-windows] build failed: $($_.Exception.Message)"
    exit 1
}