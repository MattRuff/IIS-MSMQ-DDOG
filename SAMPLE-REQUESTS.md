# Sample API Requests

This document contains sample API requests for testing the IIS MSMQ demo system.

## Prerequisites

Make sure both applications are running:
```powershell
.\run-applications.ps1
```

---

## Sender Application (Port 5001)

### 1. Health Check

**PowerShell**:
```powershell
Invoke-RestMethod -Uri "http://localhost:5001/" -Method Get
```

**Curl**:
```bash
curl http://localhost:5001/
```

**Expected Response**:
```json
{
  "service": "Sender Web App",
  "status": "Running",
  "timestamp": "2024-12-19T10:30:00.000Z"
}
```

---

### 2. Check Queue Health

**PowerShell**:
```powershell
Invoke-RestMethod -Uri "http://localhost:5001/api/order/health" -Method Get
```

**Curl**:
```bash
curl http://localhost:5001/api/order/health
```

**Expected Response**:
```json
{
  "service": "Sender Web App",
  "queueAvailable": true,
  "timestamp": "2024-12-19T10:30:00.000Z"
}
```

---

### 3. Send Test Order

**PowerShell**:
```powershell
Invoke-RestMethod -Uri "http://localhost:5001/api/order/test" -Method Get
```

**Curl**:
```bash
curl http://localhost:5001/api/order/test
```

**Expected Response**:
```json
{
  "success": true,
  "message": "Test order sent successfully",
  "order": {
    "orderId": "a1b2c3d4-e5f6-7890-abcd-1234567890ab",
    "customerName": "Test Customer",
    "productName": "Test Product",
    "quantity": 1,
    "totalAmount": 99.99,
    "orderDate": "2024-12-19T10:30:00.000Z",
    "status": "Pending"
  }
}
```

---

### 4. Send Custom Order

**PowerShell**:
```powershell
$body = @{
    customerName = "John Doe"
    productName = "Premium Widget"
    quantity = 5
    totalAmount = 299.99
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body $body -ContentType "application/json"
```

**Curl**:
```bash
curl -X POST http://localhost:5001/api/order \
  -H "Content-Type: application/json" \
  -d '{
    "customerName": "John Doe",
    "productName": "Premium Widget",
    "quantity": 5,
    "totalAmount": 299.99
  }'
```

**PowerShell (Alternative - One Liner)**:
```powershell
Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body '{"customerName":"Jane Smith","productName":"Enterprise License","quantity":100,"totalAmount":9999.99}' -ContentType "application/json"
```

**Expected Response**:
```json
{
  "success": true,
  "message": "Order sent to queue successfully",
  "orderId": "a1b2c3d4-e5f6-7890-abcd-1234567890ab",
  "timestamp": "2024-12-19T10:30:00.000Z"
}
```

---

## Receiver Application (Port 5002)

### 1. Health Check

**PowerShell**:
```powershell
Invoke-RestMethod -Uri "http://localhost:5002/" -Method Get
```

**Curl**:
```bash
curl http://localhost:5002/
```

**Expected Response**:
```json
{
  "service": "Receiver Web App",
  "status": "Running",
  "timestamp": "2024-12-19T10:30:00.000Z"
}
```

---

### 2. Check Status and Queue Depth

**PowerShell**:
```powershell
Invoke-RestMethod -Uri "http://localhost:5002/api/status/health" -Method Get
```

**Curl**:
```bash
curl http://localhost:5002/api/status/health
```

**Expected Response**:
```json
{
  "service": "Receiver Web App",
  "queueAvailable": true,
  "messagesInQueue": 3,
  "timestamp": "2024-12-19T10:30:00.000Z"
}
```

---

### 3. Get Detailed Queue Status

**PowerShell**:
```powershell
Invoke-RestMethod -Uri "http://localhost:5002/api/status/queue-status" -Method Get
```

**Curl**:
```bash
curl http://localhost:5002/api/status/queue-status
```

**Expected Response**:
```json
{
  "queueAvailable": true,
  "messageCount": 3,
  "timestamp": "2024-12-19T10:30:00.000Z"
}
```

---

## Testing Scenarios

### Scenario 1: Basic End-to-End Test

```powershell
# 1. Check sender health
Write-Host "1. Checking sender health..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "http://localhost:5001/api/order/health"

# 2. Check receiver health
Write-Host "`n2. Checking receiver health..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "http://localhost:5002/api/status/health"

# 3. Send test order
Write-Host "`n3. Sending test order..." -ForegroundColor Cyan
$result = Invoke-RestMethod -Uri "http://localhost:5001/api/order/test"
$orderId = $result.order.orderId
Write-Host "Order ID: $orderId" -ForegroundColor Green

# 4. Wait for processing
Write-Host "`n4. Waiting for processing (3 seconds)..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# 5. Check queue status
Write-Host "`n5. Checking queue status..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "http://localhost:5002/api/status/queue-status"

Write-Host "`nTest complete! Check receiver app logs for processing confirmation." -ForegroundColor Green
```

---

### Scenario 2: Load Test (Multiple Orders)

```powershell
Write-Host "Sending 10 orders..." -ForegroundColor Cyan

for ($i = 1; $i -le 10; $i++) {
    $body = @{
        customerName = "Customer $i"
        productName = "Product $i"
        quantity = $i
        totalAmount = [decimal]($i * 49.99)
    } | ConvertTo-Json
    
    $result = Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body $body -ContentType "application/json"
    Write-Host "  Order $i sent: $($result.orderId)" -ForegroundColor Green
    Start-Sleep -Milliseconds 500
}

Write-Host "`nAll orders sent!" -ForegroundColor Green
Write-Host "Check receiver app to see processing..." -ForegroundColor Yellow
```

---

### Scenario 3: Stress Test (Rapid Fire)

```powershell
Write-Host "Stress test: Sending 100 orders rapidly..." -ForegroundColor Cyan

$successCount = 0
$failCount = 0

for ($i = 1; $i -le 100; $i++) {
    try {
        $body = @{
            customerName = "Stress Test Customer $i"
            productName = "Stress Test Product"
            quantity = 1
            totalAmount = 99.99
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body $body -ContentType "application/json" | Out-Null
        $successCount++
        
        if ($i % 10 -eq 0) {
            Write-Host "  Sent $i orders..." -ForegroundColor Yellow
        }
    }
    catch {
        $failCount++
    }
}

Write-Host "`nStress test complete!" -ForegroundColor Green
Write-Host "  Success: $successCount" -ForegroundColor Green
Write-Host "  Failed: $failCount" -ForegroundColor Red

# Check queue depth
$status = Invoke-RestMethod -Uri "http://localhost:5002/api/status/queue-status"
Write-Host "  Messages in queue: $($status.messageCount)" -ForegroundColor Cyan
```

---

### Scenario 4: Different Order Types

```powershell
# Small order
$smallOrder = @{
    customerName = "Small Customer"
    productName = "Basic Widget"
    quantity = 1
    totalAmount = 9.99
} | ConvertTo-Json

Write-Host "Sending small order..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body $smallOrder -ContentType "application/json"

# Medium order
$mediumOrder = @{
    customerName = "Medium Customer"
    productName = "Standard Package"
    quantity = 10
    totalAmount = 149.99
} | ConvertTo-Json

Write-Host "Sending medium order..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body $mediumOrder -ContentType "application/json"

# Large order
$largeOrder = @{
    customerName = "Enterprise Customer"
    productName = "Enterprise License"
    quantity = 1000
    totalAmount = 99999.99
} | ConvertTo-Json

Write-Host "Sending large order..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body $largeOrder -ContentType "application/json"

Write-Host "`nAll orders sent!" -ForegroundColor Green
```

---

## Monitoring Queue

### Continuous Queue Monitoring

```powershell
Write-Host "Monitoring queue... (Press Ctrl+C to stop)" -ForegroundColor Cyan
Write-Host ""

while ($true) {
    try {
        $status = Invoke-RestMethod -Uri "http://localhost:5002/api/status/queue-status"
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "[$timestamp] Messages in queue: $($status.messageCount)" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Host "Error connecting to receiver app" -ForegroundColor Red
        break
    }
}
```

---

## Error Testing

### Test with Invalid Data

```powershell
# Missing required fields
$invalidOrder = @{
    customerName = ""
    productName = ""
} | ConvertTo-Json

Write-Host "Sending invalid order (should still work - validation not strict)..." -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body $invalidOrder -ContentType "application/json"
    Write-Host "Order accepted (validation needed!)" -ForegroundColor Red
}
catch {
    Write-Host "Order rejected: $($_.Exception.Message)" -ForegroundColor Green
}
```

---

## Using MSMQ Directly (PowerShell)

### Check Queue Exists

```powershell
$queuePath = ".\private$\OrderQueue"
[System.Messaging.MessageQueue]::Exists($queuePath)
```

### Get Message Count

```powershell
$queue = New-Object System.Messaging.MessageQueue(".\private$\OrderQueue")
$count = $queue.GetAllMessages().Length
Write-Host "Messages in queue: $count" -ForegroundColor Cyan
$queue.Dispose()
```

### Purge Queue (Clear All Messages)

```powershell
Write-Host "WARNING: This will delete all messages in the queue!" -ForegroundColor Red
$confirm = Read-Host "Type 'YES' to confirm"

if ($confirm -eq "YES") {
    $queue = New-Object System.Messaging.MessageQueue(".\private$\OrderQueue")
    $queue.Purge()
    Write-Host "Queue purged!" -ForegroundColor Green
    $queue.Dispose()
}
```

---

## Swagger UI

### Access Swagger Documentation

**Sender App**:
- URL: http://localhost:5001/swagger
- Try out all endpoints interactively

**Receiver App**:
- URL: http://localhost:5002/swagger
- View status endpoints

---

## Tips

1. **Watch Logs**: Keep an eye on both application console windows to see messages being sent and processed

2. **Queue Depth**: Use the receiver's status endpoint to monitor how many messages are waiting

3. **Processing Time**: Each message takes ~1 second to process (simulated)

4. **Datadog Traces**: If Datadog is configured, view traces at https://app.datadoghq.com/apm/traces

5. **Performance**: The receiver processes messages sequentially. Queue will grow if sender is faster than receiver

---

## Quick Reference

| Action | Command |
|--------|---------|
| Send test order | `curl http://localhost:5001/api/order/test` |
| Check sender health | `curl http://localhost:5001/api/order/health` |
| Check receiver health | `curl http://localhost:5002/api/status/health` |
| Check queue depth | `curl http://localhost:5002/api/status/queue-status` |
| View sender docs | http://localhost:5001/swagger |
| View receiver docs | http://localhost:5002/swagger |

---

## Postman Collection

Import the included `postman-collection.json` file into Postman for a complete set of pre-configured requests.

```powershell
# Open Postman and import:
# File → Import → postman-collection.json
```

