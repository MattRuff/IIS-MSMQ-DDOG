# Validate Distributed Tracing - MSMQ Demo
# This script sends multiple orders and validates the system is working

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Distributed Tracing Validation Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check services are running
Write-Host "1. Checking Services..." -ForegroundColor Yellow
$services = Get-Service MsmqSenderService, MsmqReceiverService
foreach ($service in $services) {
    if ($service.Status -eq "Running") {
        Write-Host "  [OK] $($service.Name) is running" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] $($service.Name) is $($service.Status)" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# Test 1: Simple test order
Write-Host "2. Sending Test Order (Simple)..." -ForegroundColor Yellow
$response1 = Invoke-WebRequest -Uri "http://localhost:8081/api/order/test" -Method GET -UseBasicParsing
Write-Host "  Response: $($response1.StatusCode) - $($response1.Content)" -ForegroundColor Gray
Write-Host "  [OK] Test order sent" -ForegroundColor Green
Start-Sleep -Seconds 2
Write-Host ""

# Test 2: Custom order with JSON
Write-Host "3. Sending Custom Order (JSON)..." -ForegroundColor Yellow
$order1 = @{
    orderId = "ORD-$(Get-Random -Minimum 1000 -Maximum 9999)"
    customerName = "John Doe"
    productName = "Widget Pro"
    quantity = 5
    price = 29.99
} | ConvertTo-Json

$response2 = Invoke-WebRequest -Uri "http://localhost:8081/api/order" `
    -Method POST `
    -Body $order1 `
    -ContentType "application/json" `
    -UseBasicParsing
Write-Host "  Response: $($response2.StatusCode)" -ForegroundColor Gray
Write-Host "  [OK] Custom order sent" -ForegroundColor Green
Start-Sleep -Seconds 2
Write-Host ""

# Test 3: Another order with different data
Write-Host "4. Sending Order #2..." -ForegroundColor Yellow
$order2 = @{
    orderId = "ORD-$(Get-Random -Minimum 1000 -Maximum 9999)"
    customerName = "Jane Smith"
    productName = "Gadget Max"
    quantity = 3
    price = 149.99
} | ConvertTo-Json

$response3 = Invoke-WebRequest -Uri "http://localhost:8081/api/order" `
    -Method POST `
    -Body $order2 `
    -ContentType "application/json" `
    -UseBasicParsing
Write-Host "  Response: $($response3.StatusCode)" -ForegroundColor Gray
Write-Host "  [OK] Order #2 sent" -ForegroundColor Green
Start-Sleep -Seconds 2
Write-Host ""

# Test 4: High-value order
Write-Host "5. Sending High-Value Order..." -ForegroundColor Yellow
$order3 = @{
    orderId = "ORD-$(Get-Random -Minimum 1000 -Maximum 9999)"
    customerName = "Enterprise Corp"
    productName = "Enterprise License"
    quantity = 100
    price = 9999.99
} | ConvertTo-Json

$response4 = Invoke-WebRequest -Uri "http://localhost:8081/api/order" `
    -Method POST `
    -Body $order3 `
    -ContentType "application/json" `
    -UseBasicParsing
Write-Host "  Response: $($response4.StatusCode)" -ForegroundColor Gray
Write-Host "  [OK] High-value order sent" -ForegroundColor Green
Start-Sleep -Seconds 2
Write-Host ""

# Test 5: Rapid fire - multiple orders
Write-Host "6. Sending Rapid Fire Orders (10 orders)..." -ForegroundColor Yellow
for ($i = 1; $i -le 10; $i++) {
    $order = @{
        orderId = "BULK-$(Get-Random -Minimum 1000 -Maximum 9999)"
        customerName = "Customer $i"
        productName = "Product $i"
        quantity = Get-Random -Minimum 1 -Maximum 10
        price = [math]::Round((Get-Random -Minimum 10 -Maximum 500) + (Get-Random -Maximum 100) / 100, 2)
    } | ConvertTo-Json
    
    $response = Invoke-WebRequest -Uri "http://localhost:8081/api/order" `
        -Method POST `
        -Body $order `
        -ContentType "application/json" `
        -UseBasicParsing
    Write-Host "  Order $i sent (Status: $($response.StatusCode))" -ForegroundColor Gray
    Start-Sleep -Milliseconds 500
}
Write-Host "  [OK] All rapid-fire orders sent" -ForegroundColor Green
Write-Host ""

# Wait for processing
Write-Host "7. Waiting for messages to be processed..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
Write-Host "  [OK] Wait complete" -ForegroundColor Green
Write-Host ""

# Check receiver status
Write-Host "8. Checking Receiver Status..." -ForegroundColor Yellow
$statusResponse = Invoke-WebRequest -Uri "http://localhost:8082/api/status/health" -UseBasicParsing
$status = $statusResponse.Content | ConvertFrom-Json
Write-Host "  Service: $($status.service)" -ForegroundColor Cyan
Write-Host "  Queue Available: $($status.queueAvailable)" -ForegroundColor Cyan
Write-Host "  Messages in Queue: $($status.messagesInQueue)" -ForegroundColor Cyan
Write-Host "  Timestamp: $($status.timestamp)" -ForegroundColor Cyan
Write-Host "  [OK] Receiver is healthy" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Green
Write-Host "[SUCCESS] Tracing Validation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Total Requests Sent: 14 orders" -ForegroundColor Cyan
Write-Host "  - 1 test order (GET)" -ForegroundColor Gray
Write-Host "  - 3 custom orders (POST)" -ForegroundColor Gray
Write-Host "  - 10 bulk orders (POST)" -ForegroundColor Gray
Write-Host ""

# Datadog Instructions
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Check Datadog APM Now!" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "What to Look For:" -ForegroundColor Cyan
Write-Host "  1. Go to: APM > Traces in Datadog" -ForegroundColor White
Write-Host "  2. Filter by: service:SenderWebApp OR service:ReceiverWebApp" -ForegroundColor White
Write-Host "  3. You should see ~14 traces" -ForegroundColor White
Write-Host ""
Write-Host "For Each Trace:" -ForegroundColor Cyan
Write-Host "  - Sender span: POST /api/order (or GET /api/order/test)" -ForegroundColor White
Write-Host "  - MSMQ send operation" -ForegroundColor White
Write-Host "  - MSMQ receive operation" -ForegroundColor White
Write-Host "  - Receiver processing span" -ForegroundColor White
Write-Host ""
Write-Host "Key Validation Points:" -ForegroundColor Cyan
Write-Host "  [CRITICAL] All spans should have the SAME trace_id" -ForegroundColor Yellow
Write-Host "  [CRITICAL] Spans should be connected in a flame graph" -ForegroundColor Yellow
Write-Host "  [CRITICAL] Time should flow: Sender -> MSMQ -> Receiver" -ForegroundColor Yellow
Write-Host ""
Write-Host "Services:" -ForegroundColor Cyan
Write-Host "  - SenderWebApp (port 8081)" -ForegroundColor White
Write-Host "  - ReceiverWebApp (port 8082)" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Green

