# Quick Deploy Instructions

Your IIS MSMQ Demo is now on GitHub! 🎉

## 🔗 Repository

**https://github.com/MattRuff/IIS-MSMQ-DDOG**

---

## 🚀 Deploy to Windows VM (3 Steps)

### On Your Windows VM:

```powershell
# Step 1: Clone the repository
git clone git@github.com:MattRuff/IIS-MSMQ-DDOG.git
cd IIS-MSMQ-DDOG

# Step 2: One-command setup (as Administrator)
.\build-and-run.ps1

# Step 3: Test it
.\test-system.ps1
```

**That's it!** Apps are running on:
- Sender: http://localhost:8081
- Receiver: http://localhost:8082

---

## 📋 What You Get

✅ Two .NET 8.0 Web API applications  
✅ MSMQ message queue integration  
✅ Complete documentation (11 markdown files)  
✅ PowerShell automation scripts  
✅ Postman collection  
✅ Ready for Datadog single-step instrumentation  

---

## 📚 Documentation

Start here: **[START-HERE.md](START-HERE.md)**

Or jump to:
- **[DEPLOY-TO-WINDOWS.md](DEPLOY-TO-WINDOWS.md)** - Deployment from Mac
- **[QUICK-START.md](QUICK-START.md)** - 5-minute setup
- **[DATADOG-SETUP.md](DATADOG-SETUP.md)** - Datadog APM integration
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical deep dive
- **[VALIDATION-REPORT.md](VALIDATION-REPORT.md)** - Test plan

---

## 🎯 Use Cases

Perfect for demonstrating:
- Distributed tracing with Datadog APM
- .NET IIS to MSMQ integration
- Async messaging patterns
- Single-step instrumentation

---

## 💻 Requirements

- Windows 10/11 or Server 2016+
- .NET 8.0 SDK (auto-downloads during build)
- MSMQ (installed by setup script)
- Administrator privileges (for MSMQ setup)

---

## 🐕 Adding Datadog

After the system is running, follow **[DATADOG-SETUP.md](DATADOG-SETUP.md)** to:
1. Install Datadog Agent
2. Install .NET Tracer
3. Set environment variables
4. See distributed traces!

No code changes needed - pure external instrumentation.

---

## 🔧 File Structure

```
IIS-MSMQ-DDOG/
├── SenderWebApp/          # Message sender application
├── ReceiverWebApp/        # Message receiver application
├── build-and-run.ps1      # One-command setup
├── setup-msmq.ps1         # MSMQ installation
├── test-system.ps1        # System tests
├── Documentation/         # 11 detailed guides
└── postman-collection.json
```

---

## 📞 Quick Commands

```powershell
# Deploy
git clone git@github.com:MattRuff/IIS-MSMQ-DDOG.git
.\build-and-run.ps1

# Test
curl http://localhost:8081/api/order/test

# Check status
curl http://localhost:8082/api/status/health

# Full test suite
.\test-system.ps1
```

---

## 🎉 Ready for Customer Demos!

This sandbox is production-ready code designed to showcase Datadog's distributed tracing capabilities across .NET IIS applications communicating via MSMQ.

**Clone it. Build it. Demo it.** 🚀

