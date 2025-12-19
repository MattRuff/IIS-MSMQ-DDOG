# PowerShell script to setup MSMQ on Windows
# Run this script as Administrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MSMQ Setup Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

# Check if MSMQ is already installed
Write-Host "Checking MSMQ installation status..." -ForegroundColor Yellow

$msmqInstalled = Get-WindowsFeature -Name MSMQ-Server -ErrorAction SilentlyContinue

if ($null -eq $msmqInstalled) {
    # For Windows 10/11 (Client OS)
    Write-Host "Detected Windows Client OS" -ForegroundColor Cyan
    
    $msmqFeature = Get-WindowsOptionalFeature -Online -FeatureName MSMQ-Server -ErrorAction SilentlyContinue
    
    if ($null -eq $msmqFeature -or $msmqFeature.State -eq "Disabled") {
        Write-Host "Installing MSMQ..." -ForegroundColor Yellow
        Enable-WindowsOptionalFeature -Online -FeatureName MSMQ-Server -All -NoRestart
        Write-Host "MSMQ installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "MSMQ is already installed" -ForegroundColor Green
    }
} else {
    # For Windows Server
    Write-Host "Detected Windows Server OS" -ForegroundColor Cyan
    
    if ($msmqInstalled.Installed) {
        Write-Host "MSMQ is already installed" -ForegroundColor Green
    } else {
        Write-Host "Installing MSMQ..." -ForegroundColor Yellow
        Install-WindowsFeature -Name MSMQ-Server -IncludeManagementTools
        Write-Host "MSMQ installed successfully!" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verifying MSMQ Service" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check MSMQ service status
$service = Get-Service -Name MSMQ -ErrorAction SilentlyContinue

if ($null -ne $service) {
    Write-Host "MSMQ Service Status: $($service.Status)" -ForegroundColor Green
    
    if ($service.Status -ne "Running") {
        Write-Host "Starting MSMQ service..." -ForegroundColor Yellow
        Start-Service -Name MSMQ
        Write-Host "MSMQ service started" -ForegroundColor Green
    }
} else {
    Write-Host "WARNING: MSMQ service not found. A system restart may be required." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. If prompted, restart your computer" -ForegroundColor White
Write-Host "2. Run 'dotnet restore' in the solution directory" -ForegroundColor White
Write-Host "3. Run 'dotnet build' to build the solution" -ForegroundColor White
Write-Host "4. Start both applications using the run-applications.ps1 script" -ForegroundColor White
Write-Host ""

