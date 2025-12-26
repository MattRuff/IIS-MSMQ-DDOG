# Diagnostic script to investigate MSMQ tracing
# This helps understand what Datadog is actually tracing

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MSMQ Tracing Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check if applications are running
Write-Host "1. Checking running applications..." -ForegroundColor Yellow
$sender = Get-Process -Name "SenderWebApp" -ErrorAction SilentlyContinue
$receiver = Get-Process -Name "ReceiverWebApp" -ErrorAction SilentlyContinue

if ($sender) {
    Write-Host "   [OK] SenderWebApp is running (PID: $($sender.Id))" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] SenderWebApp is not running!" -ForegroundColor Red
}

if ($receiver) {
    Write-Host "   [OK] ReceiverWebApp is running (PID: $($receiver.Id))" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] ReceiverWebApp is not running!" -ForegroundColor Red
}

Write-Host ""

# 2. Send test messages
Write-Host "2. Sending 3 test orders..." -ForegroundColor Yellow
for ($i=1; $i -le 3; $i++) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8081/api/order/test" -Method Get
        Write-Host "   [OK] Order $i sent: $($response.orderId)" -ForegroundColor Green
        Start-Sleep -Seconds 2
    } catch {
        Write-Host "   [ERROR] Failed to send order $i : $_" -ForegroundColor Red
    }
}

Write-Host ""

# 3. Wait for processing
Write-Host "3. Waiting 10 seconds for message processing..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# 4. Check queue status
Write-Host "4. Checking receiver queue status..." -ForegroundColor Yellow
try {
    $status = Invoke-RestMethod -Uri "http://localhost:8082/api/status/health"
    Write-Host "   Queue Available: $($status.queueAvailable)" -ForegroundColor Cyan
    Write-Host "   Messages in Queue: $($status.messagesInQueue)" -ForegroundColor Cyan
    
    if ($status.messagesInQueue -eq 0) {
        Write-Host "   [OK] All messages were consumed!" -ForegroundColor Green
    } else {
        Write-Host "   [WARN] $($status.messagesInQueue) messages still in queue" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   [ERROR] Could not get queue status: $_" -ForegroundColor Red
}

Write-Host ""

# 5. Check Datadog debug logs
Write-Host "5. Checking Datadog debug logs..." -ForegroundColor Yellow
$logPath = "C:\Temp\DatadogLogs"

if (Test-Path $logPath) {
    $logs = Get-ChildItem $logPath -Filter "dotnet-tracer-*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 2
    
    if ($logs) {
        Write-Host "   [OK] Found Datadog logs:" -ForegroundColor Green
        foreach ($log in $logs) {
            Write-Host "      - $($log.Name) ($(Get-Date $log.LastWriteTime -Format 'HH:mm:ss'))" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "   Searching for MSMQ-related log entries..." -ForegroundColor Cyan
        
        foreach ($log in $logs) {
            $msmqEntries = Select-String -Path $log.FullName -Pattern "msmq|MessageQueue" -CaseSensitive:$false
            
            if ($msmqEntries) {
                Write-Host ""
                Write-Host "   Found $($msmqEntries.Count) MSMQ-related entries in $($log.Name):" -ForegroundColor Yellow
                $msmqEntries | Select-Object -First 10 | ForEach-Object {
                    Write-Host "      Line $($_.LineNumber): $($_.Line.Substring(0, [Math]::Min(100, $_.Line.Length)))" -ForegroundColor Gray
                }
                
                if ($msmqEntries.Count -gt 10) {
                    Write-Host "      ... and $($msmqEntries.Count - 10) more entries" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Host "   [WARN] No Datadog log files found in $logPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "   [WARN] Datadog log directory not found: $logPath" -ForegroundColor Yellow
    Write-Host "   Debug logging may not be enabled" -ForegroundColor Gray
}

Write-Host ""

# 6. Summary and next steps
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary & Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "What to check in Datadog APM:" -ForegroundColor Yellow
Write-Host "  1. Look for traces with operation: aspnet_webapi.request" -ForegroundColor White
Write-Host "  2. Check if MSMQ spans appear as child spans" -ForegroundColor White
Write-Host "  3. Search for service: SenderWebApp and ReceiverWebApp" -ForegroundColor White
Write-Host ""

Write-Host "If MSMQ receive is NOT traced:" -ForegroundColor Yellow
Write-Host "  - Check debug logs above for 'MessageQueue' entries" -ForegroundColor White
Write-Host "  - Verify Datadog .NET Tracer version supports MSMQ" -ForegroundColor White
Write-Host "  - Consider that BeginReceive/ReceiveCompleted pattern" -ForegroundColor White
Write-Host "    may not be instrumented (only synchronous Receive())" -ForegroundColor White
Write-Host ""

Write-Host "Log locations:" -ForegroundColor Yellow
Write-Host "  Datadog Debug: $logPath" -ForegroundColor White
Write-Host "  Sender App:    .\SenderWebApp\bin\Release\net48\logs\" -ForegroundColor White
Write-Host "  Receiver App:  .\ReceiverWebApp\bin\Release\net48\logs\" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit"

