#Requires -Version 5.1
<#
.SYNOPSIS
    Bisection script to find which test creates unwanted files/state.
    PowerShell equivalent of find-polluter.sh.
.DESCRIPTION
    Runs each test file matching a pattern one by one and checks if a
    specified file or directory appears after each test.
.EXAMPLE
    .\find-polluter.ps1 .git 'src/**/*.test.ts'
    .\find-polluter.ps1 node_modules/.cache '**/*.spec.js'
#>

param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Check,

    [Parameter(Mandatory, Position = 1)]
    [string]$Pattern
)

$ErrorActionPreference = 'Stop'

Write-Host "Searching for test that creates: $Check"
Write-Host "Test pattern: $Pattern"
Write-Host ''

# Convert bash-style glob (e.g. src/**/*.test.ts) to PowerShell search
# Split on ** to get base directory and file filter
if ($Pattern -match '\*\*') {
    $parts = $Pattern -split '\*\*[/\\]?'
    $baseDir = if ($parts[0]) { $parts[0].TrimEnd('/\') } else { '.' }
    $fileFilter = if ($parts.Length -gt 1 -and $parts[1]) { $parts[1].TrimStart('/\') } else { '*' }
} else {
    # Flat pattern like "*.test.ts" — search current dir
    $baseDir = '.'
    $fileFilter = $Pattern
}

$testFiles = @(Get-ChildItem -Path $baseDir -Recurse -Include $fileFilter -File | Sort-Object FullName)
$total = $testFiles.Count
Write-Host "Found $total test files"
Write-Host ''

$count = 0
foreach ($testFile in $testFiles) {
    $count++

    # Skip if pollution already exists
    if (Test-Path $Check) {
        Write-Host "  Pollution already exists before test $count/$total"
        Write-Host "   Skipping: $($testFile.FullName)"
        continue
    }

    Write-Host "[$count/$total] Testing: $($testFile.FullName)"

    # Run the test (suppress output)
    try {
        & npm test "$($testFile.FullName)" 2>&1 | Out-Null
    }
    catch {
        # Ignore test failures
    }

    # Check if pollution appeared
    if (Test-Path $Check) {
        Write-Host ''
        Write-Host 'FOUND POLLUTER!'
        Write-Host "   Test: $($testFile.FullName)"
        Write-Host "   Created: $Check"
        Write-Host ''
        Write-Host 'Pollution details:'
        Get-Item $Check | Format-List Name, Length, LastWriteTime
        Write-Host ''
        Write-Host 'To investigate:'
        Write-Host "  npm test $($testFile.FullName)    # Run just this test"
        Write-Host "  Get-Content $($testFile.FullName)  # Review test code"
        exit 1
    }
}

Write-Host ''
Write-Host 'No polluter found - all tests clean!'
exit 0
