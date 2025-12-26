# Search for actual MSMQ instrumentation in Datadog debug logs
# This looks for evidence that Datadog is instrumenting System.Messaging methods

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Searching for MSMQ Instrumentation Evidence" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$logPath = "C:\Temp\DatadogLogs"

if (-not (Test-Path $logPath)) {
    Write-Host "[ERROR] Log directory not found: $logPath" -ForegroundColor Red
    Write-Host "Make sure you've run .\build-and-run.ps1 with debug logging enabled" -ForegroundColor Yellow
    exit
}

$logs = Get-ChildItem $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending

if (-not $logs) {
    Write-Host "[ERROR] No log files found in $logPath" -ForegroundColor Red
    exit
}

Write-Host "Searching in $($logs.Count) log file(s)..." -ForegroundColor Yellow
Write-Host ""

# Search patterns for MSMQ instrumentation
$patterns = @{
    "System.Messaging namespace" = "System\.Messaging"
    "MessageQueue class" = "MessageQueue"
    "Instrumenting methods" = "Instrumenting.*method|CallTarget.*integration"
    "MSMQ integration" = "MsmqIntegration|Msmq.*Integration"
    "Send/Receive methods" = "\.Send\(|\.Receive\(|BeginReceive|EndReceive"
    "Span creation" = "Creating span|StartActive.*msmq"
}

foreach ($pattern in $patterns.Keys) {
    Write-Host "Looking for: $pattern" -ForegroundColor Cyan
    
    $found = $false
    foreach ($log in $logs) {
        $matches = Select-String -Path $log.FullName -Pattern $patterns[$pattern] -CaseSensitive:$false
        
        if ($matches) {
            $found = $true
            Write-Host "  [FOUND] in $($log.Name):" -ForegroundColor Green
            
            $matches | Select-Object -First 5 | ForEach-Object {
                Write-Host "    Line $($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Gray
            }
            
            if ($matches.Count -gt 5) {
                Write-Host "    ... and $($matches.Count - 5) more matches" -ForegroundColor Gray
            }
        }
    }
    
    if (-not $found) {
        Write-Host "  [NOT FOUND]" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Show all enabled integrations
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Checking Enabled Integrations" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

foreach ($log in $logs) {
    $integrations = Select-String -Path $log.FullName -Pattern "Integration enabled|Registering integration" -CaseSensitive:$false
    
    if ($integrations) {
        Write-Host "Enabled integrations in $($log.Name):" -ForegroundColor Yellow
        $integrations | Select-Object -First 20 | ForEach-Object {
            Write-Host "  Line $($_.LineNumber): $($_.Line.Trim())" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Conclusion" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "If 'System.Messaging' and 'MSMQ integration' were NOT found:" -ForegroundColor Yellow
Write-Host "  -> MSMQ auto-instrumentation is NOT active" -ForegroundColor Red
Write-Host "  -> This explains why you only see HTTP traces" -ForegroundColor Red
Write-Host ""

Write-Host "Possible reasons:" -ForegroundColor Yellow
Write-Host "  1. MSMQ integration is disabled by default" -ForegroundColor White
Write-Host "  2. Only specific .NET Framework versions support it" -ForegroundColor White
Write-Host "  3. Requires additional configuration/environment variable" -ForegroundColor White
Write-Host "  4. Only works with traditional System.Messaging, not our event-driven pattern" -ForegroundColor White
Write-Host ""

Write-Host "Next step: Check Datadog tracer version and configuration" -ForegroundColor Cyan
Write-Host ""

Read-Host "Press Enter to exit"

