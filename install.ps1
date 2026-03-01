#Requires -Version 5.1
<#
.SYNOPSIS
    Installer for Astra — PowerShell equivalent of install.sh.
.DESCRIPTION
    Symlinks astra skills, agents, and config into ~/.claude/.
    On Windows without symlink support, falls back to file copies
    and writes a manifest to track what was installed.
.EXAMPLE
    .\install.ps1
#>

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$ClaudeHome = Join-Path $HOME '.claude'
$ManifestName = '.astra-manifest.json'

# --- Symlink support detection ---

function Test-SymlinkSupport {
    # PowerShell 5.1 (Desktop) only runs on Windows
    $onWindows = $PSVersionTable.PSEdition -eq 'Desktop' -or ($null -ne $IsWindows -and $IsWindows)
    if (-not $onWindows) { return $true }

    # Windows: test by actually creating a symlink
    New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null
    $testTarget = Join-Path $ClaudeHome '.astra-symlink-test-target'
    $testLink = Join-Path $ClaudeHome '.astra-symlink-test-link'
    try {
        Set-Content -Path $testTarget -Value 'test'
        New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
    finally {
        Remove-Item $testLink -ErrorAction SilentlyContinue
        Remove-Item $testTarget -ErrorAction SilentlyContinue
    }
}

$CanSymlink = Test-SymlinkSupport
$Manifest = @{}

if ($CanSymlink) { $Verb = 'Linked' } else { $Verb = 'Copied' }

# --- Helper ---

function Install-Link {
    param(
        [string]$Source,
        [string]$Destination,
        [switch]$IsDirectory
    )

    # Remove existing target (file, symlink, or directory)
    if (Test-Path $Destination) {
        Remove-Item $Destination -Recurse -Force
    }

    if ($script:CanSymlink) {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
    }
    else {
        $parentDir = Split-Path $Destination -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        if ($IsDirectory) {
            Copy-Item -Path $Source -Destination $Destination -Recurse -Force
        }
        else {
            Copy-Item -Path $Source -Destination $Destination -Force
        }
        $script:Manifest[$Destination] = $Source
    }
}

# --- Main ---

Write-Host 'Setting up Claude Code from astra...'
if (-not $CanSymlink) {
    Write-Host '  (Windows copy mode - symlinks unavailable)'
}

# Create directory structure
New-Item -ItemType Directory -Path (Join-Path $ClaudeHome 'skills') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $ClaudeHome 'plugins') -Force | Out-Null

# CLAUDE.md
Install-Link -Source (Join-Path $ScriptDir 'global' 'CLAUDE.md') `
    -Destination (Join-Path $ClaudeHome 'CLAUDE.md')
Write-Host "  $Verb CLAUDE.md"

# Plugins
Install-Link -Source (Join-Path $ScriptDir 'global' 'plugins' 'blocklist.json') `
    -Destination (Join-Path $ClaudeHome 'plugins' 'blocklist.json')
Write-Host "  $Verb plugins/blocklist.json"

# Skills (auto-discover)
$skillsDir = Join-Path $ScriptDir 'skills'
foreach ($skillDir in (Get-ChildItem -Path $skillsDir -Directory | Sort-Object Name)) {
    $dst = Join-Path $ClaudeHome 'skills' $skillDir.Name
    Install-Link -Source $skillDir.FullName -Destination $dst -IsDirectory
    Write-Host "  $Verb skill: $($skillDir.Name)"
}

# Agents (recurse into category subdirs, link flat into ~/.claude/agents/)
$agentsDir = Join-Path $ScriptDir 'agents'
New-Item -ItemType Directory -Path (Join-Path $ClaudeHome 'agents') -Force | Out-Null
$agentFiles = @(Get-ChildItem -Path $agentsDir -Filter '*.md' -Recurse |
    Where-Object { $_.Name -ne 'README.md' } |
    Sort-Object Name)
foreach ($agentFile in $agentFiles) {
    $dst = Join-Path $ClaudeHome 'agents' $agentFile.Name
    Install-Link -Source $agentFile.FullName -Destination $dst
}
Write-Host "  $Verb $($agentFiles.Count) agents"

# Settings.json
$settingsPath = Join-Path $ClaudeHome 'settings.json'
if (-not (Test-Path $settingsPath)) {
    Write-Host ''
    Write-Host '  No settings.json found. Copy the example and fill in your values:'
    $exampleSrc = Join-Path $ScriptDir 'global' 'settings.json.example'
    Write-Host "    Copy-Item '$exampleSrc' '$settingsPath'"
    Write-Host '    Then edit ~/.claude/settings.json with your API token and endpoint.'
}
else {
    Write-Host '  settings.json already exists (skipped)'
}

# Write manifest in copy mode
if (-not $CanSymlink -and $Manifest.Count -gt 0) {
    $manifestPath = Join-Path $ClaudeHome $ManifestName
    $Manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath
    Write-Host "  Wrote $ManifestName ($($Manifest.Count) entries)"
}

Write-Host ''
Write-Host 'Done. Claude Code is ready.'
