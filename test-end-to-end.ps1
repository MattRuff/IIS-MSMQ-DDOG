# Complete end-to-end test of the MSMQ system

Write-Host "`n=== END-TO-END MSMQ SYSTEM TEST ===" -ForegroundColor Cyan

# 1. Check both services are running
Write-Host "`n1. Checking Services..." -ForegroundColor Yellow
$sender = Get-Service MsmqSenderService -ErrorAction SilentlyContinue
$receiver = Get-Service MsmqReceiverService -ErrorAction SilentlyContinue

if ($sender -and $sender.Status -eq "Running") {
    Write-Host "   [OK] Sender service is running" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Sender service is NOT running!" -ForegroundColor Red
    exit 1
}

if ($receiver -and $receiver.Status -eq "Running") {
    Write-Host "   [OK] Receiver service is running" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Receiver service is NOT running!" -ForegroundColor Red
    exit 1
}

# 2. Check initial queue depth
Write-Host "`n2. Checking Initial Queue Depth..." -ForegroundColor Yellow
$queue = New-Object System.Messaging.MessageQueue(".\private$\OrderQueue")
$initialCount = $queue.GetAllMessages().Count
$queue.Dispose()
Write-Host "   Messages in queue: $initialCount" -ForegroundColor Cyan

# 3. Send a test order
Write-Host "`n3. Sending Test Order..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:8081/api/order/test" -Method Get
    Write-Host "   [OK] Order sent: $($response.order.orderId)" -ForegroundColor Green
    Write-Host "   Customer: $($response.order.customerName)" -ForegroundColor Gray
    Write-Host "   Status: $($response.order.status)" -ForegroundColor Gray
    $testOrderId = $response.order.orderId
} catch {
    Write-Host "   [ERROR] Failed to send order: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 4. Verify message was queued
Write-Host "`n4. Verifying Message Queued..." -ForegroundColor Yellow
Start-Sleep -Seconds 1
$queue = New-Object System.Messaging.MessageQueue(".\private$\OrderQueue")
$afterSendCount = $queue.GetAllMessages().Count
$queue.Dispose()

if ($afterSendCount -gt $initialCount) {
    Write-Host "   [OK] Message added to queue (count: $initialCount -> $afterSendCount)" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Queue count unchanged (might be processing very fast)" -ForegroundColor Yellow
}

# 5. Wait and verify message was processed
Write-Host "`n5. Waiting for Message Processing (10 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$queue = New-Object System.Messaging.MessageQueue(".\private$\OrderQueue")
$finalCount = $queue.GetAllMessages().Count
$queue.Dispose()

Write-Host "   Queue count: $afterSendCount -> $finalCount" -ForegroundColor Cyan

if ($finalCount -lt $afterSendCount) {
    Write-Host "   [OK] Message was processed by receiver!" -ForegroundColor Green
} elseif ($finalCount -eq 0) {
    Write-Host "   [OK] Queue is empty (message processed)" -ForegroundColor Green
} else {
    Write-Host "   [WARN] Message may still be in queue" -ForegroundColor Yellow
}

# 6. Check receiver status
Write-Host "`n6. Checking Receiver Status..." -ForegroundColor Yellow
try {
    $status = Invoke-RestMethod -Uri "http://localhost:8082/api/status/health"
    Write-Host "   [OK] Receiver is responding" -ForegroundColor Green
    Write-Host "   Queue Available: $($status.queueAvailable)" -ForegroundColor Gray
    Write-Host "   Messages in Queue: $($status.messagesInQueue)" -ForegroundColor Gray
} catch {
    Write-Host "   [ERROR] Receiver not responding: $($_.Exception.Message)" -ForegroundColor Red
}

# 7. Check logs for the order
Write-Host "`n7. Checking Logs for Order $testOrderId..." -ForegroundColor Yellow

# Check sender logs
$senderLogPath = "C:\Users\matthew.ruyffelaert\Documents\IIS-MSMQ-Lab\IIS-MSMQ-DDOG\SenderWebApp\bin\Release\net8.0\logs"
if (Test-Path $senderLogPath) {
    $latestSenderLog = Get-ChildItem $senderLogPath -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestSenderLog) {
        $senderLogs = Get-Content $latestSenderLog.FullName | Where-Object { $_ -like "*$testOrderId*" }
        if ($senderLogs) {
            Write-Host "   [OK] Found order in sender logs" -ForegroundColor Green
        } else {
            Write-Host "   [WARN] Order not found in sender logs" -ForegroundColor Yellow
        }
    }
}

# Check receiver logs
$receiverLogPath = "C:\Users\matthew.ruyffelaert\Documents\IIS-MSMQ-Lab\IIS-MSMQ-DDOG\ReceiverWebApp\bin\Release\net8.0\logs"
if (Test-Path $receiverLogPath) {
    $latestReceiverLog = Get-ChildItem $receiverLogPath -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestReceiverLog) {
        $receiverLogs = Get-Content $latestReceiverLog.FullName | Where-Object { $_ -like "*$testOrderId*" }
        if ($receiverLogs) {
            Write-Host "   [OK] Found order in receiver logs" -ForegroundColor Green
            Write-Host "   Checking for processing..." -ForegroundColor Gray
            $processed = $receiverLogs | Where-Object { $_ -like "*processed successfully*" }
            if ($processed) {
                Write-Host "   [OK] Order was PROCESSED SUCCESSFULLY!" -ForegroundColor Green
            }
        } else {
            Write-Host "   [WARN] Order not found in receiver logs yet" -ForegroundColor Yellow
        }
    }
}

# 8. Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Test Order ID: $testOrderId" -ForegroundColor White
Write-Host "  Queue Flow: $initialCount -> $afterSendCount -> $finalCount messages" -ForegroundColor White
Write-Host ""

if ($finalCount -lt $afterSendCount -or $finalCount -eq 0) {
    Write-Host "[SUCCESS] End-to-end flow is working!" -ForegroundColor Green
    Write-Host "  1. Sender received HTTP request" -ForegroundColor Green
    Write-Host "  2. Message queued in MSMQ" -ForegroundColor Green
    Write-Host "  3. Receiver processed message" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step: Check Datadog APM for distributed trace!" -ForegroundColor Yellow
} else {
    Write-Host "[WARN] Message may not have been processed yet" -ForegroundColor Yellow
    Write-Host "  Check receiver logs for errors" -ForegroundColor Yellow
}

Write-Host ""

