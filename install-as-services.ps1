# Install IIS MSMQ Demo as Windows Services
# Run this script as Administrator

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IIS MSMQ Demo - Windows Service Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$senderPath = Join-Path $scriptPath "SenderWebApp\bin\Release\net8.0\SenderWebApp.exe"
$receiverPath = Join-Path $scriptPath "ReceiverWebApp\bin\Release\net8.0\ReceiverWebApp.exe"

# Service names
$senderServiceName = "MsmqSenderService"
$receiverServiceName = "MsmqReceiverService"

if ($Uninstall) {
    Write-Host "Uninstalling services..." -ForegroundColor Yellow
    Write-Host ""
    
    # Stop and remove Sender service
    Write-Host "Removing Sender Service..." -ForegroundColor Yellow
    $service = Get-Service -Name $senderServiceName -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -eq "Running") {
            Stop-Service -Name $senderServiceName -Force
            Write-Host "  ✓ Stopped" -ForegroundColor Green
        }
        sc.exe delete $senderServiceName
        Write-Host "  ✓ Removed" -ForegroundColor Green
    } else {
        Write-Host "  Sender service not found (already removed?)" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Stop and remove Receiver service
    Write-Host "Removing Receiver Service..." -ForegroundColor Yellow
    $service = Get-Service -Name $receiverServiceName -ErrorAction SilentlyContinue
    if ($service) {
        if ($service.Status -eq "Running") {
            Stop-Service -Name $receiverServiceName -Force
            Write-Host "  ✓ Stopped" -ForegroundColor Green
        }
        sc.exe delete $receiverServiceName
        Write-Host "  ✓ Removed" -ForegroundColor Green
    } else {
        Write-Host "  Receiver service not found (already removed?)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✅ Services Uninstalled" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
}

# Install mode
Write-Host "Building applications..." -ForegroundColor Yellow
dotnet build -c Release --no-restore

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Build successful" -ForegroundColor Green
Write-Host ""

# Check if executables exist
if (-not (Test-Path $senderPath)) {
    Write-Host "❌ Sender executable not found at: $senderPath" -ForegroundColor Red
    Write-Host "Run 'dotnet build -c Release' first" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $receiverPath)) {
    Write-Host "❌ Receiver executable not found at: $receiverPath" -ForegroundColor Red
    Write-Host "Run 'dotnet build -c Release' first" -ForegroundColor Yellow
    exit 1
}

Write-Host "Installing services..." -ForegroundColor Yellow
Write-Host ""

# Install Sender Service
Write-Host "Installing Sender Service..." -ForegroundColor Yellow
$senderBinPath = "`"$senderPath`""
sc.exe create $senderServiceName binPath= $senderBinPath start= auto DisplayName= "MSMQ Sender Service"

if ($LASTEXITCODE -eq 0) {
    # Set description
    sc.exe description $senderServiceName "IIS MSMQ Demo - Sender Application (Port 8081)"
    Write-Host "  ✓ Created" -ForegroundColor Green
} else {
    Write-Host "  ❌ Failed to create service" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Install Receiver Service
Write-Host "Installing Receiver Service..." -ForegroundColor Yellow
$receiverBinPath = "`"$receiverPath`""
sc.exe create $receiverServiceName binPath= $receiverBinPath start= auto DisplayName= "MSMQ Receiver Service"

if ($LASTEXITCODE -eq 0) {
    # Set description
    sc.exe description $receiverServiceName "IIS MSMQ Demo - Receiver Application (Port 8082)"
    Write-Host "  ✓ Created" -ForegroundColor Green
} else {
    Write-Host "  ❌ Failed to create service" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Start services
Write-Host "Starting services..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Starting Sender Service..." -ForegroundColor Yellow
Start-Service -Name $senderServiceName
Start-Sleep -Seconds 2
$service = Get-Service -Name $senderServiceName
if ($service.Status -eq "Running") {
    Write-Host "  ✓ Running" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Service status: $($service.Status)" -ForegroundColor Yellow
}

Write-Host ""

Write-Host "Starting Receiver Service..." -ForegroundColor Yellow
Start-Service -Name $receiverServiceName
Start-Sleep -Seconds 2
$service = Get-Service -Name $receiverServiceName
if ($service.Status -eq "Running") {
    Write-Host "  ✓ Running" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Service status: $($service.Status)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ Services Installed and Started!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Service Details:" -ForegroundColor Cyan
Write-Host "  Sender Service: $senderServiceName" -ForegroundColor White
Write-Host "  Receiver Service: $receiverServiceName" -ForegroundColor White
Write-Host ""
Write-Host "Applications:" -ForegroundColor Cyan
Write-Host '  Sender:   http://localhost:8081' -ForegroundColor White
Write-Host '  Receiver: http://localhost:8082' -ForegroundColor White
Write-Host ""
Write-Host "Manage Services:" -ForegroundColor Yellow
Write-Host '  View:    services.msc' -ForegroundColor White
Write-Host "  Stop:    Stop-Service $senderServiceName" -ForegroundColor White
Write-Host "  Start:   Start-Service $senderServiceName" -ForegroundColor White
Write-Host "  Status:  Get-Service $senderServiceName" -ForegroundColor White
Write-Host ""
Write-Host "Uninstall:" -ForegroundColor Yellow
Write-Host '  .\install-as-services.ps1 -Uninstall' -ForegroundColor White
Write-Host ""
Write-Host "Test:" -ForegroundColor Yellow
Write-Host '  curl http://localhost:8081/api/order/test' -ForegroundColor White
Write-Host ""

