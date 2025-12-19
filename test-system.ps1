# PowerShell script to test the MSMQ system

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Testing IIS MSMQ Demo System" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Test Sender Health
Write-Host "1. Testing Sender Health..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:5001/api/order/health" -Method Get
    Write-Host "   Sender Status: OK" -ForegroundColor Green
    Write-Host "   Queue Available: $($response.queueAvailable)" -ForegroundColor Green
} catch {
    Write-Host "   ERROR: Sender app not responding" -ForegroundColor Red
    Write-Host "   Make sure the Sender app is running on port 5001" -ForegroundColor Yellow
}

Write-Host ""

# Test Receiver Health
Write-Host "2. Testing Receiver Health..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:5002/api/status/health" -Method Get
    Write-Host "   Receiver Status: OK" -ForegroundColor Green
    Write-Host "   Queue Available: $($response.queueAvailable)" -ForegroundColor Green
    Write-Host "   Messages in Queue: $($response.messagesInQueue)" -ForegroundColor Green
} catch {
    Write-Host "   ERROR: Receiver app not responding" -ForegroundColor Red
    Write-Host "   Make sure the Receiver app is running on port 5002" -ForegroundColor Yellow
}

Write-Host ""

# Send Test Order
Write-Host "3. Sending Test Order..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:5001/api/order/test" -Method Get
    Write-Host "   Test Order Sent!" -ForegroundColor Green
    Write-Host "   Order ID: $($response.order.orderId)" -ForegroundColor Cyan
    Write-Host "   Customer: $($response.order.customerName)" -ForegroundColor Cyan
    Write-Host "   Product: $($response.order.productName)" -ForegroundColor Cyan
} catch {
    Write-Host "   ERROR: Failed to send test order" -ForegroundColor Red
}

Write-Host ""

# Wait for processing
Write-Host "4. Waiting for message processing (3 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Check Queue Status
Write-Host "5. Checking Queue Status..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:5002/api/status/queue-status" -Method Get
    Write-Host "   Messages Remaining in Queue: $($response.messageCount)" -ForegroundColor Cyan
} catch {
    Write-Host "   ERROR: Failed to check queue status" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Test Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Check the Receiver application logs to see the processed order" -ForegroundColor Yellow
Write-Host ""

# Custom order example
Write-Host "To send a custom order, use this command:" -ForegroundColor Cyan
Write-Host @"
`$body = @{
    customerName = "John Doe"
    productName = "Widget"
    quantity = 5
    totalAmount = 149.99
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body `$body -ContentType "application/json"
"@ -ForegroundColor White

Write-Host ""

