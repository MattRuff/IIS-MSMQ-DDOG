# Quick Start Guide

Get the IIS MSMQ demo running in 5 minutes!

> **🍎 Mac Users**: This requires Windows. See [MAC-USERS.md](MAC-USERS.md) for VM setup instructions.

## Prerequisites Check

```powershell
# Check .NET SDK
dotnet --version
# Should be 8.0 or higher

# Check PowerShell version
$PSVersionTable.PSVersion
# Should be 5.1 or higher

# Check if running Windows
[System.Environment]::OSVersion.Platform
# Should show "Win32NT"
```

## Setup (5 Minutes)

### 1. Install MSMQ (2 minutes)

```powershell
# Open PowerShell as Administrator
.\setup-msmq.ps1
```

> ⚠️ **May require restart** - If prompted, restart and continue to step 2

### 2. Build the Solution (1 minute)

```powershell
dotnet restore
dotnet build
```

### 3. Run the Applications (1 minute)

```powershell
.\run-applications.ps1
```

Wait for both applications to start. You should see:
- Sender: http://localhost:5001
- Receiver: http://localhost:5002

### 4. Test the System (1 minute)

```powershell
.\test-system.ps1
```

You should see:
- ✅ Sender Status: OK
- ✅ Receiver Status: OK
- ✅ Test Order Sent
- ✅ Message Processed

## That's It! 🎉

Your distributed MSMQ system is running!

## Common Commands

```powershell
# Send a test order
curl http://localhost:5001/api/order/test

# Check sender health
curl http://localhost:5001/api/order/health

# Check receiver status
curl http://localhost:5002/api/status/health

# Send custom order
$body = @{
    customerName = "Jane Doe"
    productName = "Premium Widget"
    quantity = 3
    totalAmount = 199.99
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5001/api/order" `
    -Method Post `
    -Body $body `
    -ContentType "application/json"
```

## View Swagger UI

- Sender: http://localhost:5001/swagger
- Receiver: http://localhost:5002/swagger

## Next Steps

1. **Add Datadog Tracing**: See [DATADOG-SETUP.md](DATADOG-SETUP.md)
2. **Deploy to IIS**: See [README.md](README.md) IIS deployment section
3. **Customize**: Modify the code in `SenderWebApp` and `ReceiverWebApp`

## Troubleshooting

### Applications won't start

```powershell
# Check if MSMQ service is running
Get-Service MSMQ

# Start MSMQ if needed
Start-Service MSMQ
```

### Port already in use

Edit `appsettings.json` in each app:
```json
{
  "Urls": "http://localhost:5001"  // Change to available port
}
```

### Can't connect to queue

```powershell
# Verify queue exists
[System.Messaging.MessageQueue]::Exists(".\private$\OrderQueue")

# Create queue if needed
[System.Messaging.MessageQueue]::Create(".\private$\OrderQueue")
```

## File Structure

```
├── SenderWebApp/      → Sends messages to MSMQ
├── ReceiverWebApp/    → Receives and processes messages
├── setup-msmq.ps1     → Installs MSMQ
├── run-applications.ps1 → Starts both apps
├── test-system.ps1    → Tests the system
└── README.md          → Full documentation
```

## Support

- 📖 Full Documentation: [README.md](README.md)
- 🐕 Datadog Setup: [DATADOG-SETUP.md](DATADOG-SETUP.md)
- 🐛 Issues: Check application logs in PowerShell windows

