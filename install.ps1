#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Force UTF-8 for console I/O so Lua's UTF-8 output renders correctly
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

# Ensure Lua and Git are installed
foreach ($pkg in @("lua", "git"))
{
    if (-not (Get-Command $pkg -ErrorAction SilentlyContinue))
    {
        Write-Host "[*] Installing $pkg..." -ForegroundColor Yellow
        choco install $pkg -y
    }
    else
    {
        Write-Host "[+] $pkg is already installed." -ForegroundColor Green
    }
}

# The Chocolatey `lua` package bundles a stale 7z.exe in its install directory
# and adds that directory to PATH. Composer auto-detects any 7z.exe on PATH and
# prefers it over PHP's ZipArchive, but this bundled copy fails to extract
# archives containing case-only filename collisions. Remove it so Composer (and
# any other tool) falls back to its built-in extractor. Lua itself does not use
# this binary at runtime.
foreach ($luaDir in @(
    "C:\Program Files (x86)\Lua\5.1",
    "C:\Program Files\Lua\5.1"
))
{
    $stray7z = Join-Path $luaDir "7z.exe"
    if (Test-Path -LiteralPath $stray7z)
    {
        try
        {
            Remove-Item -LiteralPath $stray7z -Force
            Write-Host "[+] Removed bundled 7z.exe from $luaDir (conflicts with Composer)." -ForegroundColor Green
        }
        catch
        {
            Write-Host "[-] Failed to remove $stray7z. Re-run this script in an Administrator shell." -ForegroundColor Red
        }
    }
}

# Refresh PATH so freshly installed choco shims resolve in this session
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
    [System.Environment]::GetEnvironmentVariable("Path", "User")

$LuaCmd = Get-Command lua -ErrorAction SilentlyContinue
if (-not $LuaCmd)
{
    $chocoLua = Join-Path $env:ChocolateyInstall "bin\lua.exe"
    if ($env:ChocolateyInstall -and (Test-Path $chocoLua))
    {
        $LuaPath = $chocoLua
    }
    else
    {
        $fallback = "C:\ProgramData\chocolatey\bin\lua.exe"
        if (Test-Path $fallback)
        {
            $LuaPath = $fallback
        }
        else
        {
            Write-Host "[-] lua not found on PATH after install. Open a new shell and retry." -ForegroundColor Red
            exit 1
        }
    }
}
else
{
    $LuaPath = $LuaCmd.Source
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
& $LuaPath "$DotfilesDirectory\provision\main.lua" windows @args
