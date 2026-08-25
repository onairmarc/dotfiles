#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Force UTF-8 for console I/O so the provisioner's UTF-8 output renders correctly
# (otherwise ✓/✗/… appear as mojibake like Γ£ô / Γ£ù / ΓÇª).
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

$DotfilesRepo = "https://github.com/onairmarc/dotfiles.git"
if (-not $env:DF_ROOT_DIRECTORY)
{
    $env:DF_ROOT_DIRECTORY = Join-Path $env:USERPROFILE "Documents\GitHub\dotfiles"
}
$DotfilesDirectory = $env:DF_ROOT_DIRECTORY

# Ensure Chocolatey is installed
if (-not (Get-Command choco -ErrorAction SilentlyContinue))
{
    Write-Host "[*] Chocolatey not found. Installing Chocolatey..." -ForegroundColor Yellow
    Write-Host "[!] A User Account Control (UAC) prompt will appear to run the installation as administrator." -ForegroundColor Yellow
    Write-Host "[!] Please approve the prompt to continue." -ForegroundColor Yellow
    try
    {
        $installCommand = "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
        Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command $installCommand" -Verb RunAs -Wait
    }
    catch
    {
        Write-Host "[-] Failed to install Chocolatey. UAC prompt may have been declined or elevation failed." -ForegroundColor Red
        Write-Host "[-] Please run this script in a terminal started as Administrator and try again." -ForegroundColor Red
        exit 1
    }
    if (-not (Get-Command choco -ErrorAction SilentlyContinue))
    {
        Write-Host "[-] Chocolatey installation failed or choco is not in PATH." -ForegroundColor Red
        Write-Host "[-] Please ensure Chocolatey installed successfully or install it manually." -ForegroundColor Red
        exit 1
    }
    Write-Host "[+] Chocolatey installed successfully." -ForegroundColor Green
}
else
{
    Write-Host "[+] Chocolatey is already installed." -ForegroundColor Green
}

# Ensure Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue))
{
    Write-Host "[*] Installing git..." -ForegroundColor Yellow
    choco install git -y
}
else
{
    Write-Host "[+] git is already installed." -ForegroundColor Green
}

# Refresh PATH so freshly installed choco shims resolve in this session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User")

# Ensure Bun is installed — it is the provisioner runtime (provision\main.ts).
if (-not (Get-Command bun -ErrorAction SilentlyContinue))
{
    Write-Host "[*] Installing bun..." -ForegroundColor Yellow
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm bun.sh/install.ps1 | iex"
    # The installer adds %USERPROFILE%\.bun\bin to the User PATH; surface it now.
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
        [System.Environment]::GetEnvironmentVariable("Path", "User")
}
else
{
    Write-Host "[+] bun is already installed." -ForegroundColor Green
}

$BunCmd = Get-Command bun -ErrorAction SilentlyContinue
if (-not $BunCmd)
{
    $userBun = Join-Path $env:USERPROFILE ".bun\bin\bun.exe"
    if (Test-Path $userBun)
    {
        $BunPath = $userBun
    }
    else
    {
        Write-Host "[-] bun not found on PATH after install. Open a new shell and retry." -ForegroundColor Red
        exit 1
    }
}
else
{
    $BunPath = $BunCmd.Source
}

# Clone dotfiles repo if not present
if (-not (Test-Path $DotfilesDirectory))
{
    Write-Host "[*] Cloning dotfiles repository..." -ForegroundColor Yellow
    git clone $DotfilesRepo $DotfilesDirectory
}
else
{
    Write-Host "[+] Dotfiles directory already exists at $DotfilesDirectory." -ForegroundColor Green
}

# Symlink ~/.zshrc and ~/.bashrc to repo .zshrc
$Target = Join-Path $DotfilesDirectory ".zshrc"
foreach ($name in @(".zshrc", ".bashrc", ".bash_profile"))
{
    $rc = Join-Path $env:USERPROFILE $name
    $item = Get-Item -LiteralPath $rc -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq "SymbolicLink" -and $item.Target -eq $Target)
    {
        Write-Host "[+] $rc already symlinked to repo .zshrc." -ForegroundColor Green
        continue
    }
    if ($item)
    {
        if ($item.LinkType)
        {
            Remove-Item -LiteralPath $rc -Force
        }
        else
        {
            $backup = "$rc.bak." + (Get-Date -Format "yyyyMMddHHmmss")
            Write-Host "[*] Backing up existing $rc to $backup" -ForegroundColor Yellow
            Move-Item -LiteralPath $rc -Destination $backup
        }
    }
    try
    {
        New-Item -ItemType SymbolicLink -Path $rc -Target $Target -Force | Out-Null
        Write-Host "[+] Symlinked $rc -> $Target" -ForegroundColor Green
    }
    catch
    {
        Write-Host "[-] Failed to symlink $rc. Enable Developer Mode or run as Administrator." -ForegroundColor Red
        throw
    }
}

Set-Location $DotfilesDirectory
& $BunPath "$DotfilesDirectory\provision\main.ts" windows @args
