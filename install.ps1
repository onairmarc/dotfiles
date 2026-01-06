#Requires -Version 5.1

# Write-Host "[!] This script is not yet ready for production use." -ForegroundColor Yellow
# Write-Host "[!] Press any key to exit." -ForegroundColor Yellow
# [void][System.Console]::ReadKey($true)
# exit

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Install-ChocoTool {
    param (
        [string]$ToolName,
        [string]$ChocoId
    )

    $alreadyInstalled = "[+] $ToolName is already installed."

    # Check if the package is installed
    $chocoList = choco list --local-only $ChocoId
    if ($chocoList -match $ChocoId) {
        Write-Host $alreadyInstalled -ForegroundColor Green
    } else {
        Write-Host "[*] Installing $ToolName..." -ForegroundColor Yellow
        try {
            choco install $ChocoId -y
        } catch {
            Write-Host "[-] Failed to install $ToolName." -ForegroundColor Red
            throw $_
        }
    }
}

function Main {
    # Check if running on Windows
    if ([System.Environment]::OSVersion.Platform -ne "Win32NT") {
        Write-Host "[-] Operating System is not Windows. Cannot Run Installer." -ForegroundColor Red
        exit 1
    }

    Write-Host "Starting Windows setup..." -ForegroundColor Cyan

    # Variables
    $DotfilesRepo = "https://github.com/onairmarc/dotfiles.git"
    $DotfilesDirectory = Join-Path $env:USERPROFILE "Documents\GitHub\dotfiles"
    $EntrypointScript = Join-Path $DotfilesDirectory "entrypoint.sh"

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
        # Verify Chocolatey installation
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Host "[-] Chocolatey installation failed or choco is not in PATH." -ForegroundColor Red
            Write-Host "[-] Please ensure Chocolatey installed successfully or install it manually." -ForegroundColor Red
            exit 1
        }
        Write-Host "[+] Chocolatey installed successfully." -ForegroundColor Green
    } else {
        Write-Host "[+] Chocolatey is already installed." -ForegroundColor Green
    }

    # Ensure Git is installed
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "[*] Git not found. Installing Git..." -ForegroundColor Yellow
        Install-ChocoTool -ToolName "git" -ChocoId "git"
    } else {
        Write-Host "[+] Git is already installed." -ForegroundColor Green
    }

    # Clone dotfiles repo
    Write-Host "[*] Cloning dotfiles repository..." -ForegroundColor Yellow
    if (-not (Test-Path $DotfilesDirectory)) {
        try {
            git clone $DotfilesRepo $DotfilesDirectory | Out-Null
        } catch {
            Write-Host "[-] Failed to clone $DotfilesRepo. Directory may not be empty. Skipping this step." -ForegroundColor Red
        }
    } else {
        Write-Host "[+] Dotfiles directory already exists." -ForegroundColor Green
    }

    # Install Zsh via Chocolatey
    if (-not (Get-Command zsh -ErrorAction SilentlyContinue)) {
        Write-Host "[*] Zsh not found. Installing Zsh..." -ForegroundColor Yellow
        Install-ChocoTool -ToolName "zsh" -ChocoId "zsh"
    } else {
        Write-Host "[+] Zsh is already installed." -ForegroundColor Green
    }

    # Install software
    Install-ChocoTool -ToolName "1password" -ChocoId "1password"
    Install-ChocoTool -ToolName "1password-cli" -ChocoId "1password-cli"
    Install-ChocoTool -ToolName "chrome" -ChocoId "googlechrome"
    Install-ChocoTool -ToolName "doctl" -ChocoId "doctl"
    Install-ChocoTool -ToolName "git-extras" -ChocoId "git-extras"
    Install-ChocoTool -ToolName "htop" -ChocoId "htop"
    Install-ChocoTool -ToolName "jetbrains-toolbox" -ChocoId "jetbrainstoolbox"
    Install-ChocoTool -ToolName "jq" -ChocoId "jq"
    Install-ChocoTool -ToolName "nano" -ChocoId "nano"
    Install-ChocoTool -ToolName "rsync" -ChocoId "rsync"
    Install-ChocoTool -ToolName "saml2aws" -ChocoId "saml2aws"
    Install-ChocoTool -ToolName "terraform" -ChocoId "terraform"
    Install-ChocoTool -ToolName "tmux" -ChocoId "tmux"
    Install-ChocoTool -ToolName "zsh-autosuggestions" -ChocoId "zsh-autosuggestions"
    Install-ChocoTool -ToolName "zsh-syntax-highlighting" -ChocoId "zsh-syntax-highlighting"

    # Install OpenCode
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        Write-Host "[*] Installing OpenCode..." -ForegroundColor Yellow
        try {
            bash -c "curl -fsSL https://opencode.ai/install | bash"
            Write-Host "[+] OpenCode installation completed." -ForegroundColor Green
        } catch {
            Write-Host "[-] Failed to install OpenCode." -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Bash not found. Skipping OpenCode installation." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "[+] Setup completed! You may need to restart your terminal for some changes to take effect." -ForegroundColor Green
    Write-Host ""
}

# Execute main function
Main
