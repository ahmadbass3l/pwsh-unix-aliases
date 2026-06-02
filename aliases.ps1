# =============================================================================
# Unix/Linux Command Aliases for PowerShell 7
# Repository: https://github.com/ahmadbass3l/pwsh-unix-aliases
#
# These aliases and functions map common Unix/Linux CLI commands to their
# PowerShell equivalents on Windows. Some are thin wrappers, some are
# full function replacements that behave as closely to the original as possible.
# =============================================================================

# -----------------------------------------------------------------------------
# SECTION: File System Navigation
# -----------------------------------------------------------------------------

# ls → Get-ChildItem (with color-like formatting)
function ls   { Get-ChildItem @args }
function ll   { Get-ChildItem -Force @args }          # ls -la equivalent
function la   { Get-ChildItem -Force @args }          # ls -a
function l    { Get-ChildItem @args | Format-Wide }   # compact view

# pwd → already works in PS7, but alias for muscle memory
# (PS7 already has pwd as alias for Get-Location)

# cd  → already works; add common shortcuts
function ~    { Set-Location $HOME }
function ..   { Set-Location .. }
function ...  { Set-Location ../.. }
function .... { Set-Location ../../.. }

# mkdir -p equivalent (Create-Item creates intermediates via -Force)
function mkdirp {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

# rmdir equivalent
function rmdir-r {
    param([string]$Path)
    Remove-Item -Recurse -Force $Path
}

# touch → create empty file or update timestamp
function touch {
    param([string[]]$Files)
    foreach ($f in $Files) {
        if (Test-Path $f) {
            (Get-Item $f).LastWriteTime = Get-Date
        } else {
            New-Item -ItemType File -Path $f -Force | Out-Null
        }
    }
}

# -----------------------------------------------------------------------------
# SECTION: File Viewing & Text Processing
# -----------------------------------------------------------------------------

# cat → Get-Content
function cat   { Get-Content @args }

# head → first N lines (default 10)
function head {
    param(
        [Parameter(ValueFromPipeline=$true)] $InputObject,
        [int]$n = 10,
        [string]$Path
    )
    if ($Path) {
        Get-Content $Path | Select-Object -First $n
    } elseif ($InputObject) {
        $InputObject | Select-Object -First $n
    }
}

# tail → last N lines (default 10); -f for follow
function tail {
    param(
        [Parameter(ValueFromPipeline=$true)] $InputObject,
        [int]$n = 10,
        [switch]$f,
        [string]$Path
    )
    if ($f -and $Path) {
        Get-Content $Path -Wait -Tail $n
    } elseif ($Path) {
        Get-Content $Path | Select-Object -Last $n
    } elseif ($InputObject) {
        $InputObject | Select-Object -Last $n
    }
}

# grep → Select-String (basic passthrough with pattern + path support)
function grep {
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Pattern,
        [Parameter(ValueFromPipeline=$true)]     $InputObject,
        [Parameter(Position=1)]                  [string[]]$Path,
        [switch]$i,   # ignore case
        [switch]$r,   # recursive
        [switch]$l,   # list file names only
        [switch]$n,   # show line numbers
        [switch]$v    # invert match
    )
    $opts = @{ Pattern = $Pattern }
    if ($i) { $opts['CaseSensitive'] = $false } else { $opts['CaseSensitive'] = $true }
    if ($v) { $opts['NotMatch'] = $true }

    if ($r -and $Path) {
        Get-ChildItem -Recurse -File $Path | Select-String @opts |
            ForEach-Object {
                if ($l) { $_.Filename }
                elseif ($n) { "$($_.Filename):$($_.LineNumber): $($_.Line)" }
                else { "$($_.Filename): $($_.Line)" }
            }
    } elseif ($Path) {
        Select-String @opts -Path $Path |
            ForEach-Object {
                if ($l) { $_.Filename }
                elseif ($n) { "$($_.Filename):$($_.LineNumber): $($_.Line)" }
                else { $_.Line }
            }
    } elseif ($InputObject) {
        $InputObject | Select-String @opts |
            ForEach-Object {
                if ($n) { "$($_.LineNumber): $($_.Line)" } else { $_.Line }
            }
    }
}

# wc → measure lines/words/chars
function wc {
    param(
        [Parameter(ValueFromPipeline=$true)] $InputObject,
        [switch]$l,  # lines
        [switch]$w,  # words
        [switch]$c,  # characters
        [string]$Path
    )
    $content = if ($Path) { Get-Content $Path } else { $InputObject }
    $text = $content -join "`n"
    if ($l)     { ($text -split "`n").Count }
    elseif ($w) { ($text -split '\s+' | Where-Object { $_ -ne '' }).Count }
    elseif ($c) { $text.Length }
    else {
        $lines = ($text -split "`n").Count
        $words = ($text -split '\s+' | Where-Object { $_ -ne '' }).Count
        $chars = $text.Length
        "$lines`t$words`t$chars"
    }
}

# sort → Sort-Object (passthrough)
function sort-u {
    param([Parameter(ValueFromPipeline=$true)] $InputObject)
    $input | Sort-Object -Unique
}

# uniq → Get unique lines
function uniq {
    param([Parameter(ValueFromPipeline=$true)] $InputObject)
    $input | Get-Unique
}

# cut → select columns (delimiter-based)
function cut {
    param(
        [Parameter(ValueFromPipeline=$true)] $InputObject,
        [string]$d = "`t",   # delimiter
        [string]$f = "1"     # field number(s), e.g. "1" or "1,3"
    )
    $fields = $f -split ',' | ForEach-Object { [int]$_ - 1 }
    $input | ForEach-Object {
        $parts = $_ -split [regex]::Escape($d)
        ($fields | ForEach-Object { $parts[$_] }) -join $d
    }
}

# tr → translate/replace characters
function tr {
    param(
        [Parameter(ValueFromPipeline=$true)] $InputObject,
        [string]$From,
        [string]$To
    )
    $input | ForEach-Object {
        $line = $_
        for ($i = 0; $i -lt [Math]::Min($From.Length, $To.Length); $i++) {
            $line = $line -replace [regex]::Escape($From[$i].ToString()), $To[$i].ToString()
        }
        $line
    }
}

# sed (basic s/pattern/replacement/g)
function sed {
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Expression,
        [Parameter(ValueFromPipeline=$true)]     $InputObject
    )
    if ($Expression -match '^s/(.+)/(.*)/(g?)$') {
        $pat  = $Matches[1]
        $repl = $Matches[2]
        $glob = $Matches[3] -eq 'g'
        $input | ForEach-Object {
            if ($glob) { $_ -replace $pat, $repl }
            else       { $_ -replace "(?<first>$pat)", $repl }
        }
    } else {
        Write-Warning "sed: only basic s/pattern/replacement/[g] syntax supported"
    }
}

# awk (very basic — print specific field)
function awk {
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Program,
        [Parameter(ValueFromPipeline=$true)]     $InputObject
    )
    if ($Program -match "print\s+\\\$(\d+)") {
        $field = [int]$Matches[1] - 1
        $input | ForEach-Object { ($_ -split '\s+')[$field] }
    } else {
        Write-Warning "awk: only basic '{print `$N}' syntax supported. Use pwsh natively for complex awk."
    }
}

# -----------------------------------------------------------------------------
# SECTION: File Search & Discovery
# -----------------------------------------------------------------------------

# find → Get-ChildItem recursive wrapper
function find {
    param(
        [string]$Path = ".",
        [string]$name = "*",
        [ValidateSet("f","d","")]
        [string]$type = ""
    )
    $params = @{ Path = $Path; Recurse = $true; Filter = $name }
    if ($type -eq "f")    { $params['File']      = $true }
    elseif ($type -eq "d") { $params['Directory'] = $true }
    Get-ChildItem @params
}

# which → Get-Command location
function which {
    param([string]$Command)
    (Get-Command $Command -ErrorAction SilentlyContinue).Source
}

# whereis → all matches
function whereis {
    param([string]$Command)
    Get-Command $Command -All -ErrorAction SilentlyContinue | Select-Object Name, Source
}

# locate (basic — searches PATH)
function locate {
    param([string]$Pattern)
    Get-ChildItem -Path $env:PATH.Split(';') -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*$Pattern*" }
}

# -----------------------------------------------------------------------------
# SECTION: File Operations
# -----------------------------------------------------------------------------

# cp → Copy-Item
function cp    { Copy-Item @args }
function cp-r  {
    param([string]$Src, [string]$Dst)
    Copy-Item -Recurse -Path $Src -Destination $Dst
}

# mv → Move-Item
function mv    { Move-Item @args }

# rm → Remove-Item
function rm    { Remove-Item @args }
function rm-rf {
    param([string]$Path)
    Remove-Item -Recurse -Force $Path
}

# ln -s → New-Item -ItemType SymbolicLink
function ln-s {
    param([string]$Target, [string]$Link)
    New-Item -ItemType SymbolicLink -Path $Link -Target $Target
}

# chmod (stub — Windows ACLs differ, opens icacls docs)
function chmod {
    Write-Warning "chmod: Windows uses ACLs. Use 'icacls' or 'Set-Acl' instead."
    Write-Host "Example: icacls `"path`" /grant `"User:(R)`""
}

# chown (stub)
function chown {
    Write-Warning "chown: Windows uses 'takeown' and 'icacls' for ownership."
    Write-Host "Example: takeown /F `"path`" /R"
}

# -----------------------------------------------------------------------------
# SECTION: Process Management
# -----------------------------------------------------------------------------

# ps → Get-Process (Unix-style columns)
function ps    { Get-Process @args }

# kill → Stop-Process
function kill  {
    param([int]$PID)
    Stop-Process -Id $PID -Force
}

# killall → Stop-Process by name
function killall {
    param([string]$Name)
    Get-Process -Name $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}

# top → like htop, opens a live view
function top {
    while ($true) {
        Clear-Host
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 |
            Format-Table Name, Id, CPU, WorkingSet -AutoSize
        Start-Sleep -Seconds 2
    }
}

# bg/fg/jobs stubs (not natively supported in Windows the same way)
function jobs  { Get-Job }
function bg    { param([int]$n) Resume-Job -Id $n }
function fg    { param([int]$n) Receive-Job -Id $n -Wait }

# nohup → Start-Process detached
function nohup {
    param([string]$Command)
    Start-Process -FilePath "pwsh" -ArgumentList "-Command", $Command -WindowStyle Hidden
}

# -----------------------------------------------------------------------------
# SECTION: Disk & System Info
# -----------------------------------------------------------------------------

# df → disk free
function df {
    Get-PSDrive -PSProvider FileSystem | Select-Object Name,
        @{N='Used(GB)';E={[math]::Round($_.Used/1GB,2)}},
        @{N='Free(GB)';E={[math]::Round($_.Free/1GB,2)}},
        @{N='Total(GB)';E={[math]::Round(($_.Used+$_.Free)/1GB,2)}}
}

# du → directory size
function du {
    param([string]$Path = ".")
    Get-ChildItem -Recurse -File $Path -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum |
        ForEach-Object { "{0:N2} MB  {1}" -f ($_.Sum / 1MB), (Resolve-Path $Path) }
}

# free → memory info
function free {
    $os  = Get-CimInstance Win32_OperatingSystem
    $total = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $free  = [math]::Round($os.FreePhysicalMemory   / 1MB, 2)
    $used  = [math]::Round($total - $free, 2)
    [PSCustomObject]@{ "Total(GB)" = $total; "Used(GB)" = $used; "Free(GB)" = $free }
}

# uname → system info
function uname {
    param([switch]$a)
    $os = Get-CimInstance Win32_OperatingSystem
    if ($a) {
        "$($os.Caption) $($os.Version) $($env:COMPUTERNAME) $($env:PROCESSOR_ARCHITECTURE)"
    } else {
        $os.Caption
    }
}

# uptime
function uptime {
    $os = Get-CimInstance Win32_OperatingSystem
    $boot = $os.LastBootUpTime
    $up   = (Get-Date) - $boot
    "Up $($up.Days)d $($up.Hours)h $($up.Minutes)m since $boot"
}

# hostname
function hostname { $env:COMPUTERNAME }

# whoami → already works natively in PS7

# id → user identity
function id {
    $user  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $admin = ([System.Security.Principal.WindowsPrincipal]$user).IsInRole(
        [System.Security.Principal.WindowsBuiltInRole]::Administrator)
    "uid=$($user.Name)  isAdmin=$admin"
}

# env → environment variables
function env   { Get-ChildItem Env: | Format-Table -AutoSize }

# export VAR=val → Set-Item Env:
function export {
    param([string]$Assignment)
    if ($Assignment -match '^(\w+)=(.*)$') {
        Set-Item -Path "Env:$($Matches[1])" -Value $Matches[2]
    }
}

# printenv
function printenv {
    param([string]$Var)
    if ($Var) { [System.Environment]::GetEnvironmentVariable($Var) }
    else      { Get-ChildItem Env: }
}

# -----------------------------------------------------------------------------
# SECTION: Networking
# -----------------------------------------------------------------------------

# ping → already works natively

# curl → Invoke-RestMethod / Invoke-WebRequest wrapper
function curl {
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Uri,
        [string]$o,         # output file
        [string]$X = "GET", # method
        [string]$d,         # data/body
        [hashtable]$H = @{} # headers
    )
    $params = @{ Uri = $Uri; Method = $X; Headers = $H }
    if ($d) { $params['Body'] = $d }
    if ($o) { Invoke-WebRequest @params -OutFile $o }
    else    { Invoke-WebRequest @params | Select-Object -ExpandProperty Content }
}

# wget → download file
function wget {
    param(
        [Parameter(Mandatory=$true, Position=0)] [string]$Uri,
        [string]$OutFile
    )
    if (-not $OutFile) { $OutFile = Split-Path $Uri -Leaf }
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile
    Write-Host "Saved to: $OutFile"
}

# netstat → Get-NetTCPConnection
function netstat {
    param([switch]$a, [switch]$n, [switch]$p)
    Get-NetTCPConnection | Format-Table LocalAddress, LocalPort, RemoteAddress, RemotePort, State -AutoSize
}

# ifconfig / ip → network adapters
function ifconfig {
    Get-NetIPAddress | Format-Table InterfaceAlias, AddressFamily, IPAddress, PrefixLength -AutoSize
}
function ip { ifconfig }

# ssh → already works if OpenSSH is installed (Windows optional feature)

# scp → works if OpenSSH is installed

# nslookup → already works natively

# traceroute
function traceroute {
    param([string]$Host)
    tracert $Host
}

# dig (stub → use nslookup or Resolve-DnsName)
function dig {
    param([string]$Domain)
    Resolve-DnsName $Domain
}

# nc / ncat stub
function nc {
    Write-Warning "nc: Use 'Test-NetConnection' or install ncat from nmap. Example:"
    Write-Host "  Test-NetConnection -ComputerName hostname -Port 80"
}

# lsof (open files/ports)
function lsof {
    param([switch]$i)
    if ($i) { Get-NetTCPConnection | Format-Table -AutoSize }
    else    { Get-Process | ForEach-Object { $_.Modules } | Select-Object FileName }
}

# -----------------------------------------------------------------------------
# SECTION: Compression & Archives
# -----------------------------------------------------------------------------

# tar → wrapper around Compress-Archive / Expand-Archive
function tar {
    param(
        [string]$Flags,
        [string]$Archive,
        [string]$Target = "."
    )
    if ($Flags -match 'x') {
        Expand-Archive -Path $Archive -DestinationPath $Target -Force
    } elseif ($Flags -match 'c') {
        Compress-Archive -Path $Target -DestinationPath $Archive -Force
    } else {
        Write-Warning "tar: basic -x (extract) and -c (create) supported. Use 7-Zip for full tar support."
    }
}

# zip / unzip
function zip {
    param([string]$Archive, [string]$Source)
    Compress-Archive -Path $Source -DestinationPath $Archive -Force
}
function unzip {
    param([string]$Archive, [string]$Destination = ".")
    Expand-Archive -Path $Archive -DestinationPath $Destination -Force
}

# gzip stub
function gzip {
    Write-Warning "gzip: No native equivalent. Use 7-Zip or: Compress-Archive for .zip."
}

# -----------------------------------------------------------------------------
# SECTION: Text / Output Utilities
# -----------------------------------------------------------------------------

# echo → already works natively in PS7

# printf
function printf {
    param([string]$Format, [string[]]$Args)
    [string]::Format($Format.Replace('%s','{0}').Replace('%d','{0}'), $Args)
}

# tee → Tee-Object
function tee {
    param(
        [Parameter(ValueFromPipeline=$true)] $InputObject,
        [string]$File
    )
    $input | Tee-Object -FilePath $File
}

# less / more → Out-Host -Paging
function less  { $input | Out-Host -Paging }
function more  { $input | Out-Host -Paging }

# clear → already works natively (also cls)

# history → Get-History
function history { Get-History }

# man → Get-Help
function man {
    param([string]$Command)
    Get-Help $Command -Full
}

# which (already defined above)

# xargs → ForEach-Object
function xargs {
    param(
        [Parameter(ValueFromPipeline=$true)] $InputObject,
        [string]$Command
    )
    $input | ForEach-Object { & $Command $_ }
}

# yes → repeat string
function yes {
    param([string]$Str = "y")
    while ($true) { Write-Output $Str }
}

# -----------------------------------------------------------------------------
# SECTION: Git (bonus — already mostly works, but common shortcuts)
# -----------------------------------------------------------------------------

function gst   { git status }
function ga    { git add @args }
function gc    { git commit -m @args }
function gp    { git push @args }
function gl    { git log --oneline --graph --decorate @args }
function gco   { git checkout @args }
function gb    { git branch @args }
function gd    { git diff @args }
function gf    { git fetch @args }
function gpl   { git pull @args }

# -----------------------------------------------------------------------------
# SECTION: Misc Utilities
# -----------------------------------------------------------------------------

# date → already works; add Unix-style format option
function date-unix { Get-Date -Format "yyyy-MM-dd HH:mm:ss" }

# sleep → already works natively (Start-Sleep)

# time → Measure-Command wrapper
function time {
    param([scriptblock]$Command)
    Measure-Command { & $Command } | ForEach-Object {
        "Elapsed: $($_.TotalSeconds)s"
    }
}

# watch → repeat command every N seconds
function watch {
    param(
        [int]$n = 2,
        [scriptblock]$Command
    )
    while ($true) {
        Clear-Host
        & $Command
        Start-Sleep -Seconds $n
    }
}

# sudo → gsudo if installed, else run as admin
function sudo {
    param([string[]]$Args)
    if (Get-Command gsudo -ErrorAction SilentlyContinue) {
        gsudo @Args
    } else {
        Start-Process pwsh -Verb RunAs -ArgumentList ($Args -join ' ')
    }
}

# su (stub)
function su {
    Write-Warning "su: Use 'sudo' or open a new terminal as Administrator."
}

# diff → Compare-Object
function diff {
    param([string]$File1, [string]$File2)
    $a = Get-Content $File1
    $b = Get-Content $File2
    Compare-Object $a $b | ForEach-Object {
        if ($_.SideIndicator -eq '<=') { "< $($_.InputObject)" }
        else { "> $($_.InputObject)" }
    }
}

# md5sum / sha256sum
function md5sum {
    param([string]$Path)
    (Get-FileHash -Algorithm MD5 $Path).Hash.ToLower() + "  $Path"
}
function sha256sum {
    param([string]$Path)
    (Get-FileHash -Algorithm SHA256 $Path).Hash.ToLower() + "  $Path"
}
function sha1sum {
    param([string]$Path)
    (Get-FileHash -Algorithm SHA1 $Path).Hash.ToLower() + "  $Path"
}

# base64 encode/decode
function base64 {
    param([string]$Input, [switch]$d)
    if ($d) { [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Input)) }
    else    { [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Input)) }
}

# bc → basic calculator (evaluate math expression)
function bc {
    param([Parameter(ValueFromPipeline=$true)][string]$Expression)
    Invoke-Expression $Expression
}

# seq → generate number sequence
function seq {
    param([int]$Start, [int]$End, [int]$Step = 1)
    for ($i = $Start; $i -le $End; $i += $Step) { $i }
}

# nl → number lines
function nl {
    param([string]$Path)
    $n = 1
    Get-Content $Path | ForEach-Object { "{0,6}`t{1}" -f $n++, $_ }
}

# rev → reverse string
function rev {
    param([Parameter(ValueFromPipeline=$true)][string]$InputObject)
    $input | ForEach-Object { -join ($_[-1..-($_.Length)]) }
}

# tput (stub)
function tput {
    Write-Warning "tput: Not supported on Windows. Use ANSI escape codes directly or the 'PSReadLine' module."
}

Write-Host "[unix-aliases] Loaded. Run 'alias-list' to see all defined aliases." -ForegroundColor Cyan

function alias-list {
    Get-Command -CommandType Function |
        Where-Object { $_.Name -notmatch '^(prompt|TabExpansion|Get-Verb|.*-.*$)' } |
        Sort-Object Name |
        Format-Table Name, Definition -AutoSize
}
