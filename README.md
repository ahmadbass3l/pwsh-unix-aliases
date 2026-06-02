# pwsh-unix-aliases

A comprehensive set of Unix/Linux command aliases and function wrappers for **PowerShell 7 on Windows 11**.  
Covers ~70+ commands across file system, text processing, networking, process management, archives, and more.

---

## Quick Start

```powershell
# Clone the repo
git clone https://github.com/ahmadbass3l/pwsh-unix-aliases.git
cd pwsh-unix-aliases

# Run the installer (safe — never overwrites your profile)
.\install.ps1
```

That's it. Open a new PowerShell 7 session (or say **Y** when prompted to reload) and your Unix commands are available.

---

## What `install.ps1` does

- Locates your active `$PROFILE` for PowerShell 7 (`CurrentUserCurrentHost`)  
- Creates the profile file and its directory if they don't exist yet  
- **Duplicate check**: scans for an existing sourcing line before doing anything  
- If not already present, **appends** a single `. "path\to\aliases.ps1"` line  
- Shows the last 10 lines of your profile so you can verify  
- Offers to hot-reload in the current session  

It is **idempotent** — safe to run as many times as you like.

### Options

| Flag | Default | Description |
|------|---------|-------------|
| `-AliasFile <path>` | `.\aliases.ps1` | Override path to aliases.ps1 |
| `-ProfilePath <path>` | `$PROFILE` | Override target profile path |
| `-AutoReload` | off | Reload profile without prompting |
| `-DryRun` | off | Preview changes without writing anything |

```powershell
# Dry-run first to see what would change
.\install.ps1 -DryRun

# Point to a custom profile location
.\install.ps1 -ProfilePath "C:\Users\Ahmad\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
```

---

## Command Coverage

### File System Navigation
| Unix | PowerShell Equivalent |
|------|-----------------------|
| `ls` / `ll` / `la` | `Get-ChildItem` |
| `..` / `...` / `....` | `Set-Location ..` (chained) |
| `~` | `Set-Location $HOME` |
| `mkdirp` | `New-Item -Force` |
| `touch` | Creates file or updates timestamp |

### File Viewing & Text Processing
| Unix | PowerShell Equivalent |
|------|-----------------------|
| `cat` | `Get-Content` |
| `head -n N` | `Select-Object -First N` |
| `tail -n N` / `tail -f` | `Select-Object -Last N` / `Get-Content -Wait` |
| `grep [-i] [-r] [-l] [-n] [-v]` | `Select-String` wrapper |
| `wc [-l] [-w] [-c]` | `Measure-Object` wrapper |
| `sort -u` | `Sort-Object -Unique` |
| `uniq` | `Get-Unique` |
| `cut -d -f` | Delimiter/field splitter |
| `tr` | Character translation |
| `sed s/pat/repl/g` | `-replace` wrapper |
| `awk '{print $N}'` | Field extractor |

### File Search
| Unix | PowerShell Equivalent |
|------|-----------------------|
| `find <path> -name <pat> -type f/d` | `Get-ChildItem -Recurse` |
| `which` | `(Get-Command).Source` |
| `whereis` | `Get-Command -All` |

### File Operations
| Unix | PowerShell Equivalent |
|------|-----------------------|
| `cp` / `cp -r` | `Copy-Item` |
| `mv` | `Move-Item` |
| `rm` / `rm -rf` | `Remove-Item` |
| `ln -s` | `New-Item -ItemType SymbolicLink` |
| `chmod` / `chown` | Stubs pointing to `icacls` / `takeown` |

### Process Management
| Unix | PowerShell Equivalent |
|------|-----------------------|
| `ps` | `Get-Process` |
| `kill <pid>` | `Stop-Process -Id` |
| `killall <name>` | `Stop-Process -Name` |
| `top` | Live auto-refreshing process table |
| `jobs` / `bg` / `fg` | `Get-Job` / `Resume-Job` / `Receive-Job` |
| `nohup` | `Start-Process -WindowStyle Hidden` |

### Disk & System Info
| Unix | PowerShell Equivalent |
|------|-----------------------|
| `df` | `Get-PSDrive` |
| `du` | Recursive `Measure-Object -Sum` |
| `free` | `Win32_OperatingSystem` memory |
| `uname [-a]` | `Win32_OperatingSystem` caption |
| `uptime` | Boot time delta |
| `env` / `export` / `printenv` | `Env:` provider |
| `id` | Windows identity + admin check |

### Networking
| Unix | PowerShell Equivalent |
|------|-----------------------|
| `curl` | `Invoke-WebRequest` wrapper |
| `wget` | `Invoke-WebRequest -OutFile` |
| `netstat` | `Get-NetTCPConnection` |
| `ifconfig` / `ip` | `Get-NetIPAddress` |
| `traceroute` | `tracert` |
| `dig` | `Resolve-DnsName` |
| `lsof -i` | `Get-NetTCPConnection` |

### Archives
| Unix | PowerShell Equivalent |
|------|-----------------------|
| `tar -x` / `tar -c` | `Expand-Archive` / `Compress-Archive` |
| `zip` / `unzip` | `Compress-Archive` / `Expand-Archive` |

### Text / Output Utilities
| Unix | PowerShell Equivalent |
|------|-----------------------|
| `tee` | `Tee-Object` |
| `less` / `more` | `Out-Host -Paging` |
| `history` | `Get-History` |
| `man` | `Get-Help -Full` |
| `xargs` | `ForEach-Object` |
| `time` | `Measure-Command` |
| `watch -n N` | Auto-refreshing loop |
| `diff` | `Compare-Object` |
| `md5sum` / `sha256sum` / `sha1sum` | `Get-FileHash` |
| `base64 [-d]` | `.NET` Base64 encode/decode |
| `seq` | Number sequence generator |
| `nl` | Line numbering |

### Git Shortcuts
`gst`, `ga`, `gc`, `gp`, `gl`, `gco`, `gb`, `gd`, `gf`, `gpl`

### Misc
`sudo` (via `gsudo` if installed), `hostname`, `whoami`, `date-unix`, `bc`, `rev`

---

## Listing all aliases

After install, run:

```powershell
alias-list
```

---

## Requirements

- **PowerShell 7+** (tested on 7.4 / 7.5 on Windows 11)
- No external dependencies required
- Optional: install [gsudo](https://github.com/gerardog/gsudo) for `sudo` support

---

## License

MIT
