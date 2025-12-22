# Windows Quick Start (Real MSMQ)

Get the IIS MSMQ demo running on Windows in 3 commands!

---

## 🚀 Steps

### 1. Clone the Repo

```powershell
cd C:\
git clone https://github.com/MattRuff/IIS-MSMQ-DDOG.git
cd IIS-MSMQ-DDOG
```

### 2. Setup MSMQ (Run as Administrator)

```powershell
.\setup-msmq.ps1
```

> **Note**: May require a restart if MSMQ wasn't installed before.

### 3. Build and Run

```powershell
dotnet restore
dotnet build -c Release
.\run-applications.ps1
```

**That's it!** Two PowerShell windows will open with your apps running.

---

## ✅ Test It

```powershell
# In a new PowerShell window:

# Send test order
curl http://localhost:8081/api/order/test

# Check status
curl http://localhost:8082/api/status/health

# Or run full test suite
.\test-system.ps1
```

---

## 🌐 Open in Browser

- **Sender Swagger**: http://localhost:8081/swagger
- **Receiver Swagger**: http://localhost:8082/swagger
- **Quick Test**: http://localhost:8081/api/order/test

---

## 🎯 What You'll See

### In Sender Window:
```
info: SenderWebApp.Services.MsmqService[0]
      Queue already exists: .\private$\OrderQueue
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:8081
```

### In Receiver Window:
```
info: ReceiverWebApp.Services.MessageProcessorService[0]
      Message Processor Service started
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:8082
```

### After Sending an Order:
**Receiver window shows:**
```
info: ReceiverWebApp.Services.MsmqReceiverService[0]
      Message received successfully. OrderId: abc123...
info: ReceiverWebApp.Services.MessageProcessorService[0]
      Processing order: abc123...
info: ReceiverWebApp.Services.MessageProcessorService[0]
      Order abc123... processed successfully
```

---

## 🐕 Add Datadog (Optional)

Once this works, add Datadog APM:

1. Follow **[DATADOG-SETUP.md](DATADOG-SETUP.md)**
2. Install Datadog Agent
3. Install .NET Tracer
4. Set environment variables
5. Restart apps
6. See distributed traces!

---

## ⚠️ Troubleshooting

### "MSMQ service not running"
```powershell
Start-Service MSMQ
```

### "Port already in use"
```powershell
# Check what's using the port
netstat -ano | findstr "5001"

# Kill that process or change port in appsettings.json
```

### Build errors
```powershell
# Clean and rebuild
dotnet clean
dotnet restore --force
dotnet build -c Release
```

### "Cannot find System.Messaging"
- Make sure you're on Windows
- Run `.\setup-msmq.ps1` first
- Restart PowerShell after MSMQ installation

---

## 📝 Summary

**3 Commands. 2 Minutes. Ready for Demos!** 🚀

```powershell
git clone https://github.com/MattRuff/IIS-MSMQ-DDOG.git
cd IIS-MSMQ-DDOG
.\setup-msmq.ps1         # As Administrator
dotnet build -c Release
.\run-applications.ps1
```

