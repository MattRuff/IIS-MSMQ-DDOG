# 🚀 IIS MSMQ Distributed Tracing Demo - START HERE

Welcome! This is a complete sandbox environment for demonstrating distributed tracing with .NET IIS applications communicating via MSMQ, instrumented with Datadog APM.

---

## 📋 What's Included

This demo includes:

✅ **Two .NET 6.0 Web Applications**
- Sender App (Port 5001) - Publishes orders to MSMQ
- Receiver App (Port 5002) - Consumes and processes orders from MSMQ

✅ **MSMQ Integration**
- Private message queue for reliable async communication
- Automatic queue creation
- Message persistence

✅ **Datadog APM Ready**
- Pre-configured for single-step instrumentation
- Automatic distributed tracing across HTTP → MSMQ → Processing
- No code changes needed!

✅ **Complete Documentation**
- Quick start guides
- Detailed architecture diagrams
- API examples
- Troubleshooting guides

✅ **Testing Tools**
- PowerShell automation scripts
- Postman collection
- Sample requests

---

## 🏃 Quick Start (5 Minutes)

### Step 1: Install MSMQ
```powershell
# Run as Administrator
.\setup-msmq.ps1
```

### Step 2: Build
```powershell
dotnet restore
dotnet build
```

### Step 3: Run
```powershell
.\run-applications.ps1
```

### Step 4: Test
```powershell
.\test-system.ps1
```

**That's it!** Your distributed system is running.

👉 **Full instructions**: [QUICK-START.md](QUICK-START.md)

---

## 📚 Documentation Guide

### For Different Use Cases:

| I want to... | Read this file |
|--------------|----------------|
| **Test locally on Mac** | [MOCK-VS-REAL-MSMQ.md](MOCK-VS-REAL-MSMQ.md) 🧪 NEW! |
| **Deploy from Mac to Windows** | [DEPLOY-TO-WINDOWS.md](DEPLOY-TO-WINDOWS.md) 🍎⚡ |
| **Get started quickly (on Windows)** | [QUICK-START.md](QUICK-START.md) ⭐ |
| **Run on Mac (via Windows VM)** | [MAC-USERS.md](MAC-USERS.md) 🍎 |
| **Understand the system** | [README.md](README.md) |
| **Set up Datadog tracing** | [DATADOG-SETUP.md](DATADOG-SETUP.md) ⭐ |
| **See architecture details** | [ARCHITECTURE.md](ARCHITECTURE.md) |
| **Try API requests** | [SAMPLE-REQUESTS.md](SAMPLE-REQUESTS.md) |
| **Use Postman** | Import [postman-collection.json](postman-collection.json) |

---

## 🗂️ Project Structure

```
IIS-MSMQ-Demo/
│
├── 📄 START-HERE.md              ← You are here!
├── 📄 QUICK-START.md             ← 5-minute quick start guide
├── 📄 MAC-USERS.md               ← Guide for running on Mac (via Windows VM)
├── 📄 README.md                  ← Complete documentation
├── 📄 DATADOG-SETUP.md           ← Datadog instrumentation guide
├── 📄 ARCHITECTURE.md            ← System architecture & design
├── 📄 SAMPLE-REQUESTS.md         ← API request examples
├── 📄 postman-collection.json    ← Postman API collection
│
├── 🔧 IIS-MSMQ-Demo.sln          ← Visual Studio solution
├── 🔧 .gitignore                 ← Git ignore rules
│
├── 📜 setup-msmq.ps1              ← MSMQ installation script
├── 📜 run-applications.ps1        ← Start both applications
├── 📜 test-system.ps1             ← Test the system
│
├── 📁 SenderWebApp/              ← Message sender application
│   ├── Controllers/
│   │   └── OrderController.cs     (REST API endpoints)
│   ├── Services/
│   │   ├── IMsmqService.cs
│   │   └── MsmqService.cs         (MSMQ publishing logic)
│   ├── Models/
│   │   └── OrderMessage.cs        (Data model)
│   ├── Program.cs
│   ├── appsettings.json
│   └── SenderWebApp.csproj
│
└── 📁 ReceiverWebApp/            ← Message receiver application
    ├── Controllers/
    │   └── StatusController.cs    (Status endpoints)
    ├── Services/
    │   ├── IMsmqReceiverService.cs
    │   ├── MsmqReceiverService.cs (MSMQ consumption logic)
    │   └── MessageProcessorService.cs (Background processing)
    ├── Models/
    │   └── OrderMessage.cs        (Data model)
    ├── Program.cs
    ├── appsettings.json
    └── ReceiverWebApp.csproj
```

---

## 🎯 Common Tasks

### Testing

```powershell
# Send a test order
curl http://localhost:5001/api/order/test

# Send a custom order
$order = @{
    customerName = "John Doe"
    productName = "Widget"
    quantity = 5
    totalAmount = 149.99
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body $order -ContentType "application/json"

# Check queue status
curl http://localhost:5002/api/status/health
```

### Monitoring

- **Sender App**: http://localhost:5001/swagger
- **Receiver App**: http://localhost:5002/swagger
- **Datadog APM**: https://app.datadoghq.com/apm/traces (after setup)

### Development

```powershell
# Run sender only
cd SenderWebApp
dotnet run

# Run receiver only
cd ReceiverWebApp
dotnet run

# Build specific project
dotnet build SenderWebApp/SenderWebApp.csproj

# Clean solution
dotnet clean
```

---

## 🐕 Adding Datadog Tracing

### Quick Setup (3 Steps)

1. **Install Datadog Agent**
   ```powershell
   # Download and install from:
   # https://app.datadoghq.com/account/settings/agent/latest?platform=windows
   ```

2. **Install .NET Tracer**
   ```powershell
   # Download MSI from:
   # https://github.com/DataDog/dd-trace-dotnet/releases
   # Install: datadog-dotnet-apm-{version}-x64.msi
   ```

3. **Set Environment Variables**
   ```powershell
   $env:CORECLR_ENABLE_PROFILING=1
   $env:CORECLR_PROFILER="{846F5F1C-F9AE-4B07-969E-05C26BC060D8}"
   $env:CORECLR_PROFILER_PATH="C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll"
   $env:DD_DOTNET_TRACER_HOME="C:\Program Files\Datadog\.NET Tracer"
   $env:DD_ENV="sandbox"
   $env:DD_SERVICE="iis-msmq-demo"
   $env:DD_TRACE_MSMQ_ENABLED="true"
   
   # Then run applications
   .\run-applications.ps1
   ```

👉 **Full Datadog setup**: [DATADOG-SETUP.md](DATADOG-SETUP.md)

---

## 🔍 What You'll See in Datadog

Once instrumented, Datadog will show a complete distributed trace:

```
HTTP POST /api/order (Sender)
  └─ msmq.send (Sender)
      └─ msmq.receive (Receiver)
          └─ order.process (Receiver)
```

**Key Metrics**:
- End-to-end latency
- MSMQ queue depth
- Processing time per order
- Error rates
- Throughput

---

## 🎓 Learning Path

### For Beginners
1. Start with [QUICK-START.md](QUICK-START.md)
2. Run the system and test with [test-system.ps1](test-system.ps1)
3. Try examples from [SAMPLE-REQUESTS.md](SAMPLE-REQUESTS.md)
4. Read [README.md](README.md) for detailed explanations

### For Developers
1. Understand architecture in [ARCHITECTURE.md](ARCHITECTURE.md)
2. Explore the code in `SenderWebApp/` and `ReceiverWebApp/`
3. Modify `MessageProcessorService.cs` to add custom logic
4. Add database persistence with Entity Framework

### For Datadog Users
1. Set up tracing with [DATADOG-SETUP.md](DATADOG-SETUP.md)
2. Generate traffic with [SAMPLE-REQUESTS.md](SAMPLE-REQUESTS.md) load tests
3. View traces in Datadog APM
4. Create custom dashboards and monitors

### For DevOps/SRE
1. Deploy to IIS (see [README.md](README.md))
2. Configure application pools with Datadog environment variables
3. Set up alerts and monitors in Datadog
4. Scale to multiple instances

---

## 🛠️ System Requirements

### Minimum
- **Windows 10/11** or Windows Server 2016+
- .NET 6.0 SDK
- 2 GB RAM
- PowerShell 5.1+

### Recommended
- Windows 10/11 Pro or Windows Server 2019+
- .NET 6.0 or .NET 7.0 SDK
- 4 GB RAM
- PowerShell 7+
- Visual Studio 2022 or VS Code

### For Datadog
- Datadog account with APM enabled
- Datadog Agent installed
- Datadog .NET Tracer

### 🍎 Mac Users
**This requires Windows** (MSMQ is Windows-only). See [MAC-USERS.md](MAC-USERS.md) for:
- Setting up Windows VM (Parallels, UTM, Azure)
- Transferring files to Windows
- Accessing apps from Mac browser

---

## 🔧 Troubleshooting

### Applications won't start?

```powershell
# Check .NET SDK
dotnet --version

# Check MSMQ service
Get-Service MSMQ

# Start MSMQ
Start-Service MSMQ
```

### Queue issues?

```powershell
# Verify queue exists
[System.Messaging.MessageQueue]::Exists(".\private$\OrderQueue")

# Create queue manually
[System.Messaging.MessageQueue]::Create(".\private$\OrderQueue")
```

### No traces in Datadog?

1. Verify Datadog Agent is running: `Get-Service datadogagent`
2. Check environment variables are set
3. Enable debug logging: `$env:DD_TRACE_DEBUG="true"`
4. See [DATADOG-SETUP.md](DATADOG-SETUP.md) troubleshooting section

### Port conflicts?

Edit `appsettings.json` in each app and change the port:
```json
{
  "Urls": "http://localhost:5001"
}
```

---

## 📞 Support & Resources

### Documentation
- [README.md](README.md) - Complete documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical deep dive
- [DATADOG-SETUP.md](DATADOG-SETUP.md) - Datadog integration

### External Resources
- [MSMQ Documentation](https://docs.microsoft.com/en-us/dotnet/api/system.messaging)
- [Datadog .NET APM](https://docs.datadoghq.com/tracing/setup_overview/setup/dotnet-core/)
- [ASP.NET Core Docs](https://docs.microsoft.com/en-us/aspnet/core/)

---

## 🎉 Next Steps

1. ✅ Run the quick start: [QUICK-START.md](QUICK-START.md)
2. 🐕 Add Datadog tracing: [DATADOG-SETUP.md](DATADOG-SETUP.md)
3. 🔨 Customize the code for your use case
4. 📊 Create Datadog dashboards
5. 🚀 Deploy to IIS for production testing

---

## 📝 License & Usage

This is a demo/sandbox project for learning and testing purposes. Feel free to:
- Modify the code
- Use it for customer demos
- Extend it for your specific needs
- Share with colleagues

---

## 🙏 Feedback

Found an issue? Have suggestions? 
- Check the troubleshooting sections in documentation
- Review application logs
- Consult Datadog documentation

---

**Happy tracing! 🚀**

Made for demonstrating Datadog's distributed tracing capabilities with .NET and MSMQ.

