# Comprehensive diagnostics for the event-driven receiver

Write-Host "`n=== RECEIVER DIAGNOSTICS ===" -ForegroundColor Cyan

# 1. Check if service is running
Write-Host "`n1. Service Status:" -ForegroundColor Yellow
Get-Service -Name "MsmqReceiverService" | Format-List Status, StartType

# 2. Get latest logs from Event Viewer
Write-Host "`n2. Latest Receiver Logs (Application Event Log):" -ForegroundColor Yellow
try {
    Get-EventLog -LogName Application -Source ReceiverWebApp -Newest 20 | 
        Select-Object TimeGenerated, EntryType, Message | 
        Format-Table -AutoSize -Wrap
} catch {
    Write-Host "Could not read Event Log: $_" -ForegroundColor Red
}

# 3. Check log file if it exists
Write-Host "`n3. Latest Log File Entries:" -ForegroundColor Yellow
$logPath = "C:\Users\matthew.ruyffelaert\Documents\IIS-MSMQ-Lab\IIS-MSMQ-DDOG\ReceiverWebApp\bin\Release\net8.0\logs"
if (Test-Path $logPath) {
    $latestLog = Get-ChildItem $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestLog) {
        Write-Host "Reading: $($latestLog.FullName)" -ForegroundColor Gray
        Get-Content $latestLog.FullName -Tail 30
    } else {
        Write-Host "No log files found in $logPath" -ForegroundColor Red
    }
} else {
    Write-Host "Log directory does not exist: $logPath" -ForegroundColor Red
}

# 4. Check MSMQ queue status
Write-Host "`n4. MSMQ Queue Status:" -ForegroundColor Yellow
try {
    $queue = New-Object System.Messaging.MessageQueue(".\private$\OrderQueue")
    $messageCount = $queue.GetAllMessages().Count
    Write-Host "Queue exists: YES" -ForegroundColor Green
    Write-Host "Messages in queue: $messageCount" -ForegroundColor $(if ($messageCount -gt 0) { "Yellow" } else { "Green" })
} catch {
    Write-Host "Error accessing queue: $_" -ForegroundColor Red
}

# 5. Check if port is listening
Write-Host "`n5. Port 8082 Status:" -ForegroundColor Yellow
$port = netstat -ano | findstr "8082"
if ($port) {
    Write-Host "Port 8082 is in use:" -ForegroundColor Green
    Write-Host $port
} else {
    Write-Host "Port 8082 is NOT in use (receiver may not be running)" -ForegroundColor Red
}

# 6. Try to hit the receiver status endpoint
Write-Host "`n6. Receiver API Status Check:" -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8082/api/status/health" -TimeoutSec 5
    $status = $response.Content | ConvertFrom-Json
    Write-Host "Receiver is responding!" -ForegroundColor Green
    Write-Host "Queue Available: $($status.queueAvailable)"
    Write-Host "Messages in Queue: $($status.messagesInQueue)"
} catch {
    Write-Host "Receiver is NOT responding: $_" -ForegroundColor Red
}

Write-Host "`n=== END DIAGNOSTICS ===" -ForegroundColor Cyan
Write-Host "`nPlease share this complete output." -ForegroundColor White

