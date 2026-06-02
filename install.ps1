#!/usr/bin/env pwsh
# =============================================================================
# install.ps1 — Safely append unix-aliases to your PowerShell 7 profile
#
# What this script does:
#   1. Locates your active $PROFILE (creates it if missing)
#   2. Checks whether a sourcing line for aliases.ps1 already exists
#   3. If NOT present → appends a dot-source line to the bottom of your profile
#   4. Offers to reload the profile in the current session
#
# It NEVER overwrites your profile, NEVER deletes existing content.
# Safe to run multiple times — idempotent.
# =============================================================================

[CmdletBinding()]
param(
    # Path to aliases.ps1 — defaults to the folder this install.ps1 lives in
    [string]$AliasFile = (Join-Path $PSScriptRoot "aliases.ps1"),

    # Override the target profile (defaults to the current PowerShell 7 profile)
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,

    # If set, automatically reload profile after install without prompting
    [switch]$AutoReload,

    # Dry-run: show what would happen without making any changes
    [switch]$DryRun
)

# ── Helpers ─────────────────────────────────────────────────────────────────

function Write-Step {
    param([string]$Message, [string]$Color = "Cyan")
    Write-Host "  >> $Message" -ForegroundColor $Color
}

function Write-Success { param([string]$m) Write-Host "  [OK] $m" -ForegroundColor Green }
function Write-Info    { param([string]$m) Write-Host "  [i]  $m" -ForegroundColor Yellow }
function Write-Err     { param([string]$m) Write-Host "  [!]  $m" -ForegroundColor Red }

# ── Validate alias file exists ───────────────────────────────────────────────

Write-Host ""
Write-Host "PowerShell 7 Unix-Aliases Installer" -ForegroundColor Magenta
Write-Host "=====================================" -ForegroundColor Magenta
Write-Host ""

if (-not (Test-Path $AliasFile)) {
    Write-Err "aliases.ps1 not found at: $AliasFile"
    Write-Info "Either place install.ps1 next to aliases.ps1, or pass -AliasFile <path>"
    exit 1
}

# Resolve to absolute path so the sourcing line is always unambiguous
$AliasFile = (Resolve-Path $AliasFile).Path
Write-Step "Alias file   : $AliasFile"
Write-Step "Target profile: $ProfilePath"
Write-Host ""

# ── Ensure profile file (and its directory) exist ────────────────────────────

$profileDir = Split-Path $ProfilePath -Parent

if (-not (Test-Path $profileDir)) {
    Write-Info "Profile directory does not exist. Creating: $profileDir"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
}

if (-not (Test-Path $ProfilePath)) {
    Write-Info "Profile file does not exist. It will be created: $ProfilePath"
    if (-not $DryRun) {
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
    }
}

# ── Duplicate check ──────────────────────────────────────────────────────────
#
# We look for ANY line that dot-sources the exact same aliases.ps1 path,
# covering both `. "path"` and `. 'path'` styles and extra whitespace.
#
$escapedPath    = [regex]::Escape($AliasFile)
$alreadyPresent = $false

if (Test-Path $ProfilePath) {
    $profileContent = Get-Content $ProfilePath -Raw
    # Match: ^\s*\.\s+["']?<escaped_path>["']?\s*$
    if ($profileContent -match "(?m)^\s*\.\s+[`"']?$escapedPath[`"']?\s*$") {
        $alreadyPresent = $true
    }
    # Also match if it's sourced via a variable like $PSScriptRoot
    if ($profileContent -match "unix-aliases[/\\]aliases\.ps1") {
        $alreadyPresent = $true
    }
}

# ── Append or skip ───────────────────────────────────────────────────────────

$lineToAppend = "`n# --- Unix aliases (added by install.ps1) ---`n. `"$AliasFile`"`n"

if ($alreadyPresent) {
    Write-Info "aliases.ps1 is already sourced in your profile. Nothing to do."
} else {
    if ($DryRun) {
        Write-Info "[DRY RUN] Would append the following to ${ProfilePath}:"
        Write-Host $lineToAppend -ForegroundColor DarkGray
    } else {
        Add-Content -Path $ProfilePath -Value $lineToAppend -Encoding UTF8
        Write-Success "Appended sourcing line to: $ProfilePath"
    }
}

# ── Show profile tail for confirmation ───────────────────────────────────────

Write-Host ""
Write-Step "Last 10 lines of your profile (for verification):" "DarkCyan"
Write-Host ""
if (Test-Path $ProfilePath) {
    Get-Content $ProfilePath | Select-Object -Last 10 |
        ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
}
Write-Host ""

# ── Offer to reload ──────────────────────────────────────────────────────────

if ($DryRun) {
    Write-Info "Dry-run complete. No files were modified."
    exit 0
}

if ($AutoReload) {
    Write-Step "Reloading profile..."
    . $PROFILE
    Write-Success "Profile reloaded. Unix aliases are active in this session."
} else {
    $answer = Read-Host "  Reload profile now to activate aliases in this session? [Y/n]"
    if ($answer -eq '' -or $answer -match '^[Yy]') {
        . $PROFILE
        Write-Success "Profile reloaded. Unix aliases are active."
    } else {
        Write-Info "Reload skipped. Open a new PowerShell 7 session or run:  . `$PROFILE"
    }
}

Write-Host ""
Write-Host "  Done. Run 'alias-list' to browse all available Unix aliases." -ForegroundColor Magenta
Write-Host ""
