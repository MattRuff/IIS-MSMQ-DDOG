# One-command build and run script for Windows VM
# This does everything: setup MSMQ, build, and run

param(
    [switch]$SkipMsmqSetup
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IIS MSMQ Demo - One-Command Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "⚠️  WARNING: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "MSMQ setup requires admin privileges" -ForegroundColor Yellow
    Write-Host ""
}

# Step 1: Setup MSMQ
if (-not $SkipMsmqSetup) {
    Write-Host "STEP 1: Setting up MSMQ..." -ForegroundColor Yellow
    
    if (-not $isAdmin) {
        Write-Host "Skipping MSMQ setup (requires admin)" -ForegroundColor Yellow
        Write-Host "Run this manually: .\setup-msmq.ps1 (as Administrator)" -ForegroundColor Yellow
    } else {
        .\setup-msmq.ps1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ MSMQ setup failed" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "Skipping MSMQ setup (--SkipMsmqSetup flag)" -ForegroundColor Gray
}

Write-Host ""

# Step 2: Check .NET SDK
Write-Host "STEP 2: Checking .NET SDK..." -ForegroundColor Yellow
$dotnetVersion = dotnet --version 2>$null

if (-not $dotnetVersion) {
    Write-Host "❌ .NET SDK not found!" -ForegroundColor Red
    Write-Host "Download from: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ .NET SDK found: $dotnetVersion" -ForegroundColor Green
Write-Host ""

# Step 3: Restore dependencies
Write-Host "STEP 3: Restoring NuGet packages..." -ForegroundColor Yellow
dotnet restore --nologo

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Restore failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Packages restored" -ForegroundColor Green
Write-Host ""

# Step 4: Build solution
Write-Host "STEP 4: Building solution..." -ForegroundColor Yellow
dotnet build -c Release --no-restore --nologo -v minimal

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Build successful" -ForegroundColor Green
Write-Host ""

# Step 5: Run applications
Write-Host "STEP 5: Starting applications..." -ForegroundColor Yellow
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Start Sender
Write-Host "  → Starting Sender App (Port 5001)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$scriptPath\SenderWebApp\bin\Release\net8.0'; dotnet SenderWebApp.dll"

Start-Sleep -Seconds 2

# Start Receiver
Write-Host "  → Starting Receiver App (Port 5002)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$scriptPath\ReceiverWebApp\bin\Release\net8.0'; dotnet ReceiverWebApp.dll"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Applications:" -ForegroundColor Yellow
Write-Host "  Sender:   http://localhost:8081" -ForegroundColor White
Write-Host "  Receiver: http://localhost:8082" -ForegroundColor White
Write-Host ""
Write-Host "Swagger UI:" -ForegroundColor Yellow
Write-Host "  http://localhost:8081/swagger" -ForegroundColor White
Write-Host "  http://localhost:8082/swagger" -ForegroundColor White
Write-Host ""
Write-Host "Test the system:" -ForegroundColor Yellow
Write-Host "  .\test-system.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Or send a test order:" -ForegroundColor Yellow
Write-Host '  curl http://localhost:8081/api/order/test' -ForegroundColor White
Write-Host ""
Write-Host "Two PowerShell windows have opened showing the running apps." -ForegroundColor Gray
Write-Host "Close those windows to stop the applications." -ForegroundColor Gray
Write-Host ""

Read-Host "Press Enter to exit (apps will continue running)"

