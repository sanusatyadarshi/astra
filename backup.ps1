#Requires -Version 5.1
<#
.SYNOPSIS
    Backup for Astra — PowerShell equivalent of backup.sh.
.DESCRIPTION
    Copies live ~/.claude/ content back into the astra repo, resolving
    symlinks and stripping secrets from settings.json.
.EXAMPLE
    .\backup.ps1
#>

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$ClaudeHome = Join-Path $HOME '.claude'

# --- Helpers ---

function Test-SamePath {
    param([string]$A, [string]$B)
    try {
        $resolvedA = (Resolve-Path $A -ErrorAction Stop).Path
        $resolvedB = (Resolve-Path $B -ErrorAction Stop).Path
        return $resolvedA -eq $resolvedB
    }
    catch {
        return $false
    }
}

function Backup-SingleFile {
    <# Returns $true if backed up, 'synced' if already in sync, $false if missing #>
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path $Source)) { return $false }
    if (Test-SamePath $Source $Destination) { return 'synced' }
    $parentDir = Split-Path $Destination -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    # Resolve symlinks by using resolved path
    $resolvedSource = (Resolve-Path $Source).Path
    Copy-Item -Path $resolvedSource -Destination $Destination -Force
    return $true
}

function Backup-Directory {
    <# Returns $true if backed up, 'synced' if already in sync, $false if missing #>
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path $Source)) { return $false }
    if (Test-SamePath $Source $Destination) { return 'synced' }
    if (Test-Path $Destination) {
        Remove-Item $Destination -Recurse -Force
    }
    $resolvedSource = (Resolve-Path $Source).Path
    Copy-Item -Path $resolvedSource -Destination $Destination -Recurse -Force
    return $true
}

# --- Main ---

Write-Host 'Backing up Claude config to astra...'

# Backup CLAUDE.md
$src = Join-Path $ClaudeHome 'CLAUDE.md'
$dst = Join-Path $ScriptDir 'global' 'CLAUDE.md'
$result = Backup-SingleFile -Source $src -Destination $dst
if ($result -eq 'synced') { Write-Host '  CLAUDE.md already in sync (symlinked)' }
elseif ($result -eq $true) { Write-Host '  Backed up CLAUDE.md' }
else { Write-Host '  Skipped CLAUDE.md (not found)' }

# Backup plugins
$src = Join-Path $ClaudeHome 'plugins' 'blocklist.json'
$dst = Join-Path $ScriptDir 'global' 'plugins' 'blocklist.json'
$result = Backup-SingleFile -Source $src -Destination $dst
if ($result -eq 'synced') { Write-Host '  plugins/blocklist.json already in sync (symlinked)' }
elseif ($result -eq $true) { Write-Host '  Backed up plugins/blocklist.json' }
else { Write-Host '  Skipped blocklist.json (not found)' }

# Backup skills
$skillsDir = Join-Path $ClaudeHome 'skills'
if (Test-Path $skillsDir) {
    foreach ($skillDir in (Get-ChildItem -Path $skillsDir -Directory | Sort-Object Name)) {
        $dst = Join-Path $ScriptDir 'skills' $skillDir.Name
        if (Test-SamePath $skillDir.FullName $dst) {
            Write-Host "  Skill $($skillDir.Name) already in sync (symlinked)"
        }
        else {
            $result = Backup-Directory -Source $skillDir.FullName -Destination $dst
            if ($result -and $result -ne 'synced') {
                Write-Host "  Backed up skill: $($skillDir.Name)"
            }
        }
    }
}

# Backup agents
$agentsDir = Join-Path $ClaudeHome 'agents'
$agentSyncCount = 0
if (Test-Path $agentsDir) {
    foreach ($agentFile in (Get-ChildItem -Path $agentsDir -Filter '*.md' | Sort-Object Name)) {
        # If symlink pointing into our repo, it's already in sync
        if ($agentFile.LinkType -eq 'SymbolicLink') {
            $realTarget = (Resolve-Path $agentFile.FullName -ErrorAction SilentlyContinue).Path
            $repoAgents = Join-Path $ScriptDir 'agents'
            if ($realTarget -and $realTarget.StartsWith($repoAgents)) {
                $agentSyncCount++
                continue
            }
        }
        # Non-symlinked agent: back up
        $dst = Join-Path $ScriptDir 'agents' $agentFile.Name
        $result = Backup-SingleFile -Source $agentFile.FullName -Destination $dst
        if ($result -and $result -ne 'synced') {
            Write-Host "  Backed up agent: $($agentFile.Name)"
        }
    }
}
if ($agentSyncCount -gt 0) {
    Write-Host "  $agentSyncCount agents already in sync (symlinked)"
}

# Update settings example (strip secrets)
$settingsPath = Join-Path $ClaudeHome 'settings.json'
if (Test-Path $settingsPath) {
    try {
        $cfg = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($cfg.env) {
            $cfg.env.PSObject.Properties | ForEach-Object {
                $k = $_.Name
                $upper = $k.ToUpper()
                if ($upper -match 'TOKEN|KEY|SECRET|PASSWORD') {
                    $cfg.env.$k = '<your-' + $k.ToLower().Replace('_', '-') + '>'
                }
                elseif ($upper -match 'URL') {
                    $cfg.env.$k = '<your-api-endpoint>'
                }
            }
        }
        $examplePath = Join-Path $ScriptDir 'global' 'settings.json.example'
        $cfg | ConvertTo-Json -Depth 10 | Set-Content -Path $examplePath
        Write-Host '  Updated settings.json.example (secrets stripped)'
    }
    catch {
        Write-Host "  Warning: could not process settings.json: $_"
    }
}

Write-Host ''
Write-Host "Done. Review changes with: cd $ScriptDir; git diff"
