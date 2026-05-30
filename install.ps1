#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$DotfilesRepo = "https://github.com/onairmarc/dotfiles.git"
if (-not $env:DF_ROOT_DIRECTORY) {
    $env:DF_ROOT_DIRECTORY = Join-Path $env:USERPROFILE "Documents\GitHub\dotfiles"
}
$DotfilesDirectory = $env:DF_ROOT_DIRECTORY

# Ensure Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Chocolatey not found. Installing Chocolatey..." -ForegroundColor Yellow
    Write-Host "[!] A User Account Control (UAC) prompt will appear to run the installation as administrator." -ForegroundColor Yellow
    Write-Host "[!] Please approve the prompt to continue." -ForegroundColor Yellow
    try {
        $installCommand = "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $installCommand" -Verb RunAs -Wait
    } catch {
        Write-Host "[-] Failed to install Chocolatey. UAC prompt may have been declined or elevation failed." -ForegroundColor Red
        Write-Host "[-] Please run this script in a terminal started as Administrator and try again." -ForegroundColor Red
        exit 1
    }
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "[-] Chocolatey installation failed or choco is not in PATH." -ForegroundColor Red
        Write-Host "[-] Please ensure Chocolatey installed successfully or install it manually." -ForegroundColor Red
        exit 1
    }
    Write-Host "[+] Chocolatey installed successfully." -ForegroundColor Green
} else {
    Write-Host "[+] Chocolatey is already installed." -ForegroundColor Green
}

# Ensure Lua and Git are installed
foreach ($pkg in @("lua", "git")) {
    if (-not (Get-Command $pkg -ErrorAction SilentlyContinue)) {
        Write-Host "[*] Installing $pkg..." -ForegroundColor Yellow
        choco install $pkg -y
    } else {
        Write-Host "[+] $pkg is already installed." -ForegroundColor Green
    }
}

# Clone dotfiles repo if not present
if (-not (Test-Path $DotfilesDirectory)) {
    Write-Host "[*] Cloning dotfiles repository..." -ForegroundColor Yellow
    git clone $DotfilesRepo $DotfilesDirectory
} else {
    Write-Host "[+] Dotfiles directory already exists at $DotfilesDirectory." -ForegroundColor Green
}

# Symlink ~/.zshrc and ~/.bashrc to repo .zshrc
$Target = Join-Path $DotfilesDirectory ".zshrc"
foreach ($name in @(".zshrc", ".bashrc")) {
    $rc = Join-Path $env:USERPROFILE $name
    $item = Get-Item -LiteralPath $rc -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq "SymbolicLink" -and $item.Target -eq $Target) {
        Write-Host "[+] $rc already symlinked to repo .zshrc." -ForegroundColor Green
        continue
    }
    if ($item) {
        if ($item.LinkType) {
            Remove-Item -LiteralPath $rc -Force
        } else {
            $backup = "$rc.bak." + (Get-Date -Format "yyyyMMddHHmmss")
            Write-Host "[*] Backing up existing $rc to $backup" -ForegroundColor Yellow
            Move-Item -LiteralPath $rc -Destination $backup
        }
    }
    try {
        New-Item -ItemType SymbolicLink -Path $rc -Target $Target -Force | Out-Null
        Write-Host "[+] Symlinked $rc -> $Target" -ForegroundColor Green
    } catch {
        Write-Host "[-] Failed to symlink $rc. Enable Developer Mode or run as Administrator." -ForegroundColor Red
        throw
    }
}

Set-Location $DotfilesDirectory
lua "$DotfilesDirectory\provision\main.lua" windows @args
