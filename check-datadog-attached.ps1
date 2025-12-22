# Check if Datadog profiler is actually attached to running processes

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Datadog Profiler Attachment Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Find running processes
$senderProcess = Get-Process -Name "SenderWebApp" -ErrorAction SilentlyContinue
$receiverProcess = Get-Process -Name "ReceiverWebApp" -ErrorAction SilentlyContinue

Write-Host "1. Process Status:" -ForegroundColor Yellow
if ($senderProcess) {
    Write-Host "  [OK] SenderWebApp is running (PID: $($senderProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] SenderWebApp is NOT running" -ForegroundColor Red
}

if ($receiverProcess) {
    Write-Host "  [OK] ReceiverWebApp is running (PID: $($receiverProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] ReceiverWebApp is NOT running" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. Environment Variables (for NEW processes):" -ForegroundColor Yellow
$ddVars = @(
    "COR_ENABLE_PROFILING",
    "COR_PROFILER",
    "COR_PROFILER_PATH_64",
    "DD_DOTNET_TRACER_HOME",
    "DD_LOGS_INJECTION",
    "DD_RUNTIME_METRICS_ENABLED"
)

foreach ($var in $ddVars) {
    $value = [Environment]::GetEnvironmentVariable($var, [System.EnvironmentVariableTarget]::Process)
    if ($value) {
        Write-Host "  [OK] $var = $value" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] $var not set in current session" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "3. Testing Receiver Endpoint:" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8082/api/status/health" -UseBasicParsing
    Write-Host "  [OK] Receiver responded with status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "  Response: $($response.Content)" -ForegroundColor Gray
} catch {
    Write-Host "  [ERROR] Cannot reach receiver: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Checking Loaded Modules (if running):" -ForegroundColor Yellow
if ($receiverProcess) {
    try {
        $modules = $receiverProcess.Modules | Where-Object { $_.ModuleName -like "*Datadog*" }
        if ($modules) {
            Write-Host "  [OK] Datadog modules loaded in ReceiverWebApp:" -ForegroundColor Green
            foreach ($module in $modules) {
                Write-Host "    - $($module.ModuleName)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  [ERROR] NO Datadog modules found in ReceiverWebApp process!" -ForegroundColor Red
            Write-Host "  This means the profiler is NOT attached!" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [WARN] Cannot check modules: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($senderProcess) {
    try {
        $modules = $senderProcess.Modules | Where-Object { $_.ModuleName -like "*Datadog*" }
        if ($modules) {
            Write-Host "  [OK] Datadog modules loaded in SenderWebApp:" -ForegroundColor Green
            foreach ($module in $modules) {
                Write-Host "    - $($module.ModuleName)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  [ERROR] NO Datadog modules found in SenderWebApp process!" -ForegroundColor Red
            Write-Host "  This means the profiler is NOT attached!" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [WARN] Cannot check modules: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Diagnosis:" -ForegroundColor Yellow
Write-Host ""
Write-Host "If NO Datadog modules are loaded:" -ForegroundColor White
Write-Host "  1. Environment variables must be set BEFORE starting the app" -ForegroundColor Gray
Write-Host "  2. Restart the applications using .\build-and-run.ps1" -ForegroundColor Gray
Write-Host "  3. Check that Datadog .NET Tracer is installed" -ForegroundColor Gray
Write-Host ""
Write-Host "If Datadog modules ARE loaded but no traces appear:" -ForegroundColor White
Write-Host "  1. Check Datadog Agent is running: Get-Service datadog-agent" -ForegroundColor Gray
Write-Host "  2. Check Agent logs: C:\ProgramData\Datadog\logs\agent.log" -ForegroundColor Gray
Write-Host "  3. Verify API key is configured in Datadog Agent" -ForegroundColor Gray
Write-Host ""

