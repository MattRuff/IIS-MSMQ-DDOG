# Quick start script with Datadog instrumentation
# Use this to start the applications with Datadog APM enabled

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting MSMQ Demo with Datadog APM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check if executables exist
$senderExe = Join-Path $scriptPath "SenderWebApp\bin\Release\net48\SenderWebApp.exe"
$receiverExe = Join-Path $scriptPath "ReceiverWebApp\bin\Release\net48\ReceiverWebApp.exe"

if (!(Test-Path $senderExe)) {
    Write-Host "[ERROR] Sender executable not found!" -ForegroundColor Red
    Write-Host "  Expected: $senderExe" -ForegroundColor Yellow
    Write-Host "  Run: .\build-and-run.ps1 first" -ForegroundColor Yellow
    exit 1
}

if (!(Test-Path $receiverExe)) {
    Write-Host "[ERROR] Receiver executable not found!" -ForegroundColor Red
    Write-Host "  Expected: $receiverExe" -ForegroundColor Yellow
    Write-Host "  Run: .\build-and-run.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Datadog configuration script
$datadogSetup = @"
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Datadog APM Configuration' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

# Set Datadog environment variables for .NET Framework
`$env:COR_ENABLE_PROFILING='1'
`$env:COR_PROFILER='{846F5F1C-F9AE-4B07-969E-05C26BC060D8}'
`$env:COR_PROFILER_PATH_64='C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll'
`$env:COR_PROFILER_PATH_32='C:\Program Files\Datadog\.NET Tracer\win-x86\Datadog.Trace.ClrProfiler.Native.dll'
`$env:DD_DOTNET_TRACER_HOME='C:\Program Files\Datadog\.NET Tracer'
`$env:DD_INTEGRATIONS='C:\Program Files\Datadog\.NET Tracer\integrations.json'

# Additional Datadog settings
`$env:DD_LOGS_INJECTION='true'
`$env:DD_RUNTIME_METRICS_ENABLED='true'

Write-Host '[OK] Datadog Profiler: ENABLED' -ForegroundColor Green
Write-Host '[OK] Logs Injection: ENABLED' -ForegroundColor Green
Write-Host '[OK] Runtime Metrics: ENABLED' -ForegroundColor Green
Write-Host ''

"@

# Start Sender
Write-Host "Starting Sender Application (Port 8081)..." -ForegroundColor Yellow
$senderCommand = $datadogSetup + @"
Write-Host 'Launching Sender...' -ForegroundColor Cyan
cd '$scriptPath\SenderWebApp\bin\Release\net48'
.\SenderWebApp.exe
"@
Start-Process powershell -ArgumentList "-NoExit", "-Command", $senderCommand

Start-Sleep -Seconds 3

# Start Receiver
Write-Host "Starting Receiver Application (Port 8082)..." -ForegroundColor Yellow
$receiverCommand = $datadogSetup + @"
Write-Host 'Launching Receiver...' -ForegroundColor Cyan
cd '$scriptPath\ReceiverWebApp\bin\Release\net48'
.\ReceiverWebApp.exe
"@
Start-Process powershell -ArgumentList "-NoExit", "-Command", $receiverCommand

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Applications Started!" -ForegroundColor Green
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
Write-Host "  curl http://localhost:8081/api/order/test" -ForegroundColor Cyan
Write-Host "  curl http://localhost:8082/api/status/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "Check Datadog APM:" -ForegroundColor Yellow
Write-Host "  https://app.datadoghq.com/apm/traces" -ForegroundColor Cyan
Write-Host ""
Write-Host "Two PowerShell windows have opened with Datadog instrumentation." -ForegroundColor Gray
Write-Host "Close those windows to stop the applications." -ForegroundColor Gray
Write-Host ""

