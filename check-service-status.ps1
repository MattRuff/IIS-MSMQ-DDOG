# Quick service status check

Write-Host "`n=== SERVICE STATUS ===" -ForegroundColor Cyan

# Check service status
$sender = Get-Service -Name "MsmqSenderService" -ErrorAction SilentlyContinue
$receiver = Get-Service -Name "MsmqReceiverService" -ErrorAction SilentlyContinue

Write-Host "`nSender Service:" -ForegroundColor Yellow
if ($sender) {
    Write-Host "  Status: $($sender.Status)" -ForegroundColor $(if ($sender.Status -eq "Running") { "Green" } else { "Red" })
    Write-Host "  Start Type: $($sender.StartType)"
} else {
    Write-Host "  NOT INSTALLED" -ForegroundColor Red
}

Write-Host "`nReceiver Service:" -ForegroundColor Yellow
if ($receiver) {
    Write-Host "  Status: $($receiver.Status)" -ForegroundColor $(if ($receiver.Status -eq "Running") { "Green" } else { "Red" })
    Write-Host "  Start Type: $($receiver.StartType)"
} else {
    Write-Host "  NOT INSTALLED" -ForegroundColor Red
}

# Check ports
Write-Host "`n=== PORT STATUS ===" -ForegroundColor Cyan
Write-Host "`nPort 8081 (Sender):"
$port8081 = netstat -ano | findstr "8081"
if ($port8081) {
    Write-Host $port8081 -ForegroundColor Green
} else {
    Write-Host "  NOT LISTENING" -ForegroundColor Red
}

Write-Host "`nPort 8082 (Receiver):"
$port8082 = netstat -ano | findstr "8082"
if ($port8082) {
    Write-Host $port8082 -ForegroundColor Green
} else {
    Write-Host "  NOT LISTENING" -ForegroundColor Red
}

# Get latest errors from Event Log
Write-Host "`n=== RECENT ERRORS ===" -ForegroundColor Cyan

Write-Host "`nSender Errors:" -ForegroundColor Yellow
try {
    $senderErrors = Get-EventLog -LogName Application -Source SenderWebApp -EntryType Error -Newest 3 -ErrorAction SilentlyContinue
    if ($senderErrors) {
        $senderErrors | ForEach-Object {
            Write-Host "  [$($_.TimeGenerated)] $($_.Message.Substring(0, [Math]::Min(200, $_.Message.Length)))..." -ForegroundColor Red
        }
    } else {
        Write-Host "  No recent errors" -ForegroundColor Green
    }
} catch {
    Write-Host "  Could not read event log" -ForegroundColor Gray
}

Write-Host "`nReceiver Errors:" -ForegroundColor Yellow
try {
    $receiverErrors = Get-EventLog -LogName Application -Source ReceiverWebApp -EntryType Error -Newest 3 -ErrorAction SilentlyContinue
    if ($receiverErrors) {
        $receiverErrors | ForEach-Object {
            Write-Host "  [$($_.TimeGenerated)] $($_.Message.Substring(0, [Math]::Min(200, $_.Message.Length)))..." -ForegroundColor Red
        }
    } else {
        Write-Host "  No recent errors" -ForegroundColor Green
    }
} catch {
    Write-Host "  Could not read event log" -ForegroundColor Gray
}

Write-Host "`n=== MANUAL START ATTEMPT ===" -ForegroundColor Cyan
Write-Host "`nTrying to start services manually..." -ForegroundColor Yellow

if ($sender -and $sender.Status -ne "Running") {
    Write-Host "`nStarting Sender..."
    try {
        Start-Service -Name "MsmqSenderService" -ErrorAction Stop
        Start-Sleep -Seconds 2
        $sender.Refresh()
        Write-Host "  Status: $($sender.Status)" -ForegroundColor $(if ($sender.Status -eq "Running") { "Green" } else { "Red" })
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        
        # Get Windows Service Manager error
        Write-Host "`n  Checking Windows Event Log for service start failure..." -ForegroundColor Gray
        $serviceError = Get-EventLog -LogName System -Source "Service Control Manager" -Newest 5 -ErrorAction SilentlyContinue | 
            Where-Object { $_.Message -like "*MsmqSenderService*" }
        if ($serviceError) {
            Write-Host "  System Log: $($serviceError[0].Message)" -ForegroundColor Red
        }
    }
}

if ($receiver -and $receiver.Status -ne "Running") {
    Write-Host "`nStarting Receiver..."
    try {
        Start-Service -Name "MsmqReceiverService" -ErrorAction Stop
        Start-Sleep -Seconds 2
        $receiver.Refresh()
        Write-Host "  Status: $($receiver.Status)" -ForegroundColor $(if ($receiver.Status -eq "Running") { "Green" } else { "Red" })
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        
        # Get Windows Service Manager error
        Write-Host "`n  Checking Windows Event Log for service start failure..." -ForegroundColor Gray
        $serviceError = Get-EventLog -LogName System -Source "Service Control Manager" -Newest 5 -ErrorAction SilentlyContinue | 
            Where-Object { $_.Message -like "*MsmqReceiverService*" }
        if ($serviceError) {
            Write-Host "  System Log: $($serviceError[0].Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n"

