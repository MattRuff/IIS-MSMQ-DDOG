# Check Datadog tracer version and configuration
# This helps diagnose why MSMQ might not be instrumented

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Datadog Tracer Configuration Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check Datadog installation
Write-Host "1. Datadog .NET Tracer Installation:" -ForegroundColor Yellow
$tracerPath = "C:\Program Files\Datadog\.NET Tracer"

if (Test-Path $tracerPath) {
    Write-Host "   [OK] Found at: $tracerPath" -ForegroundColor Green
    
    # Check version
    $versionFile = Join-Path $tracerPath "version.txt"
    if (Test-Path $versionFile) {
        $version = Get-Content $versionFile
        Write-Host "   Version: $version" -ForegroundColor Cyan
    } else {
        Write-Host "   [WARN] version.txt not found" -ForegroundColor Yellow
    }
    
    # Check for integrations.json
    $integrationsFile = Join-Path $tracerPath "integrations.json"
    if (Test-Path $integrationsFile) {
        Write-Host "   [OK] integrations.json exists" -ForegroundColor Green
        
        # Search for MSMQ in integrations
        $content = Get-Content $integrationsFile -Raw
        if ($content -match "msmq|MessageQueue") {
            Write-Host "   [OK] MSMQ mentioned in integrations.json" -ForegroundColor Green
        } else {
            Write-Host "   [WARN] MSMQ NOT found in integrations.json" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   [ERROR] integrations.json not found!" -ForegroundColor Red
    }
} else {
    Write-Host "   [ERROR] Datadog .NET Tracer not found!" -ForegroundColor Red
    Write-Host "   Install from: https://github.com/DataDog/dd-trace-dotnet/releases" -ForegroundColor Yellow
}

Write-Host ""

# 2. Check environment variables
Write-Host "2. Environment Variables:" -ForegroundColor Yellow

$envVars = @{
    "COR_ENABLE_PROFILING" = $env:COR_ENABLE_PROFILING
    "COR_PROFILER" = $env:COR_PROFILER
    "DD_DOTNET_TRACER_HOME" = $env:DD_DOTNET_TRACER_HOME
    "DD_TRACE_DEBUG" = $env:DD_TRACE_DEBUG
    "DD_INTEGRATIONS" = $env:DD_INTEGRATIONS
    "DD_TRACE_ENABLED" = $env:DD_TRACE_ENABLED
    "DD_TRACE_MSMQ_ENABLED" = $env:DD_TRACE_MSMQ_ENABLED
}

foreach ($key in $envVars.Keys) {
    $value = $envVars[$key]
    if ($value) {
        Write-Host "   $key = $value" -ForegroundColor Green
    } else {
        Write-Host "   $key = (not set)" -ForegroundColor Gray
    }
}

Write-Host ""

# 3. Check running processes
Write-Host "3. Running Application Processes:" -ForegroundColor Yellow

$processes = @("SenderWebApp", "ReceiverWebApp")
foreach ($procName in $processes) {
    $proc = Get-Process -Name $procName -ErrorAction SilentlyContinue
    
    if ($proc) {
        Write-Host "   $procName (PID: $($proc.Id))" -ForegroundColor Green
        
        # Try to get environment variables (requires elevated privileges)
        try {
            $wmi = Get-WmiObject Win32_Process -Filter "ProcessId = $($proc.Id)"
            $cmdLine = $wmi.CommandLine
            
            if ($cmdLine -match "COR_ENABLE_PROFILING") {
                Write-Host "     -> Profiler env vars detected in command line" -ForegroundColor Cyan
            }
        } catch {
            # Silent fail - WMI access may require admin
        }
    } else {
        Write-Host "   $procName - NOT RUNNING" -ForegroundColor Red
    }
}

Write-Host ""

# 4. Check integrations.json content for MSMQ
Write-Host "4. MSMQ Integration Details:" -ForegroundColor Yellow

if (Test-Path $integrationsFile) {
    try {
        $json = Get-Content $integrationsFile | ConvertFrom-Json
        
        # Search for MSMQ integration
        $msmqIntegration = $json | Where-Object { $_.name -match "msmq" -or $_.name -match "MessageQueue" }
        
        if ($msmqIntegration) {
            Write-Host "   [FOUND] MSMQ Integration:" -ForegroundColor Green
            $msmqIntegration | Format-List | Out-String | ForEach-Object { 
                $_.Split("`n") | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
            }
        } else {
            Write-Host "   [NOT FOUND] No MSMQ integration in integrations.json" -ForegroundColor Red
            Write-Host "   This likely means MSMQ auto-instrumentation is not available" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   [ERROR] Could not parse integrations.json: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   [ERROR] integrations.json not found" -ForegroundColor Red
}

Write-Host ""

# 5. Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Key Findings:" -ForegroundColor Yellow
Write-Host "  - If MSMQ is NOT in integrations.json:" -ForegroundColor White
Write-Host "    -> Auto-instrumentation is not available for your tracer version" -ForegroundColor White
Write-Host ""
Write-Host "  - If DD_TRACE_MSMQ_ENABLED is not set:" -ForegroundColor White
Write-Host "    -> Try setting it to 'true' explicitly" -ForegroundColor White
Write-Host ""

Write-Host "Recommended Actions:" -ForegroundColor Cyan
Write-Host "  1. Check tracer version - may need latest version for MSMQ support" -ForegroundColor White
Write-Host "  2. Run: .\search-instrumentation-logs.ps1 to check actual instrumentation" -ForegroundColor White
Write-Host "  3. If MSMQ truly isn't supported, update documentation accordingly" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit"

