# Mock vs Real MSMQ Mode

This project supports two modes:

## 🧪 **MOCK MODE** (Current Default)
- ✅ Works on **Mac, Linux, and Windows**
- ✅ No MSMQ installation needed
- ✅ Uses in-memory queue
- ✅ Perfect for testing API structure
- ⚠️ Messages DON'T flow between apps (separate processes, separate memory)
- ⚠️ Receiver won't see messages from Sender (unless on same server)

## 🪟 **REAL MSMQ MODE**
- ✅ Real Windows MSMQ
- ✅ Messages flow between apps properly
- ✅ Ready for Datadog distributed tracing
- ⚠️ Windows only
- ⚠️ Requires MSMQ installation

---

## 🔄 Switching Between Modes

### To Use MOCK Mode (for local testing)

**Already configured!** Just build and run.

```bash
# On Mac/Linux/Windows
dotnet build
dotnet run --project SenderWebApp
dotnet run --project ReceiverWebApp
```

### To Use REAL MSMQ Mode (Windows only)

**Step 1: Rename files back**

```powershell
# In SenderWebApp/Services/
mv MsmqService.cs.windows MsmqService.cs

# In ReceiverWebApp/Services/  
mv MsmqReceiverService.cs.windows MsmqReceiverService.cs
```

**Step 2: Update Program.cs files**

In `SenderWebApp/Program.cs`:
```csharp
// MOCK MODE (comment this out)
// builder.Services.AddSingleton<SenderWebApp.Services.IMsmqService, SenderWebApp.Services.MockMsmqService>();

// REAL MSMQ MODE (uncomment this)
builder.Services.AddSingleton<SenderWebApp.Services.IMsmqService, SenderWebApp.Services.MsmqService>();
```

In `ReceiverWebApp/Program.cs`:
```csharp
// MOCK MODE (comment this out)
// builder.Services.AddSingleton<ReceiverWebApp.Services.IMsmqReceiverService, ReceiverWebApp.Services.MockMsmqReceiverService>();

// REAL MSMQ MODE (uncomment this)
builder.Services.AddSingleton<ReceiverWebApp.Services.IMsmqReceiverService, ReceiverWebApp.Services.MsmqReceiverService>();
```

**Step 3: Build and run on Windows**

```powershell
.\setup-msmq.ps1  # If not already installed
dotnet build -c Release
.\run-applications.ps1
```

---

## 📊 Feature Comparison

| Feature | Mock Mode | Real MSMQ Mode |
|---------|-----------|----------------|
| **Platform** | Mac/Linux/Windows | Windows only |
| **Setup** | None | Install MSMQ |
| **Build** | Anywhere | Windows only |
| **Message Flow** | In-memory (per process) | Real queue |
| **Distributed Trace** | ❌ No | ✅ Yes |
| **API Testing** | ✅ Yes | ✅ Yes |
| **End-to-End Testing** | ❌ No | ✅ Yes |

---

## 🎯 Use Cases

### Use Mock Mode When:
- ✅ Testing API endpoints
- ✅ Developing on Mac/Linux
- ✅ Validating REST API structure
- ✅ Testing controllers and routing
- ✅ Building without MSMQ

### Use Real MSMQ Mode When:
- ✅ End-to-end testing needed
- ✅ Demonstrating to customers
- ✅ Testing Datadog distributed tracing
- ✅ Running in production-like environment
- ✅ Windows VM available

---

## 🧪 Testing Mock Mode

```bash
# Terminal 1: Start Sender
cd SenderWebApp
dotnet run

# Terminal 2: Start Receiver  
cd ReceiverWebApp
dotnet run

# Terminal 3: Test Sender API
curl http://localhost:5001/api/order/test
# ✅ Should return success

# Test Receiver API
curl http://localhost:5002/api/status/health
# ✅ Should return health status

# Note: Receiver won't process Sender's messages in mock mode
# Each app has its own in-memory queue
```

---

## 🪟 Testing Real MSMQ Mode

```powershell
# After switching to Real MSMQ mode and building on Windows:

# Start apps
.\run-applications.ps1

# Send test order
curl http://localhost:5001/api/order/test

# Watch Receiver window - you'll see:
# "Message received successfully. OrderId: xxx"
# "Order xxx processed successfully"

# Check queue status
curl http://localhost:5002/api/status/health
# Should show messagesInQueue: 0 (processed)
```

---

## 🔧 Current Configuration

**Mode**: 🧪 **MOCK** (in-memory queue)

**To switch to Real MSMQ**: Follow "Switching Between Modes" above

**File Locations**:
- Mock implementations: `MockMsmqService.cs`, `MockMsmqReceiverService.cs`
- Real implementations: `MsmqService.cs.windows`, `MsmqReceiverService.cs.windows`

---

## 💡 Pro Tip

Keep both versions in your repo:
- Use `.windows` extension for real MSMQ files
- Keep them excluded from Mac builds
- Easy to switch when needed

This way you can develop on Mac and deploy to Windows! 🚀

