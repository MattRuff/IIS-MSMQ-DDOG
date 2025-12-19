# PowerShell script to run both Sender and Receiver applications
# This script starts both applications in separate PowerShell windows

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting IIS MSMQ Demo Applications" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Start Sender Application
Write-Host "Starting Sender Web App (Port 5001)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$scriptPath\SenderWebApp'; dotnet run"

# Wait a bit before starting the second app
Start-Sleep -Seconds 2

# Start Receiver Application
Write-Host "Starting Receiver Web App (Port 5002)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$scriptPath\ReceiverWebApp'; dotnet run"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Applications Starting!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Sender App will be available at: http://localhost:5001" -ForegroundColor Cyan
Write-Host "Receiver App will be available at: http://localhost:5002" -ForegroundColor Cyan
Write-Host ""
Write-Host "Swagger UI:" -ForegroundColor Yellow
Write-Host "  Sender:   http://localhost:5001/swagger" -ForegroundColor White
Write-Host "  Receiver: http://localhost:5002/swagger" -ForegroundColor White
Write-Host ""
Write-Host "Test the system:" -ForegroundColor Yellow
Write-Host "  curl http://localhost:5001/api/order/test" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop this script (applications will continue running)" -ForegroundColor Gray
Write-Host "To stop applications, close their PowerShell windows" -ForegroundColor Gray
Write-Host ""

# Keep this window open
Read-Host "Press Enter to exit"

