# Running as Windows Services

Run the IIS MSMQ demo as background Windows Services instead of console applications.

---

## 🚀 Quick Install

```powershell
# Build first
dotnet build -c Release

# Install and start as services (as Administrator)
.\install-as-services.ps1
```

**That's it!** Both apps are now running as Windows Services in the background.

---

## ✅ What This Does

- ✅ Installs **MsmqSenderService** (Port 8081)
- ✅ Installs **MsmqReceiverService** (Port 8082)
- ✅ Sets to **start automatically** on boot
- ✅ Runs in **background** (no console windows)
- ✅ Survives reboots

---

## 🎯 Manage Services

### View Services

```powershell
# Open Services Management Console
services.msc

# Or via PowerShell
Get-Service MsmqSenderService
Get-Service MsmqReceiverService
```

### Stop Services

```powershell
Stop-Service MsmqSenderService
Stop-Service MsmqReceiverService
```

### Start Services

```powershell
Start-Service MsmqSenderService
Start-Service MsmqReceiverService
```

### Restart Services

```powershell
Restart-Service MsmqSenderService
Restart-Service MsmqReceiverService
```

### Check Status

```powershell
Get-Service MsmqSenderService, MsmqReceiverService | Format-Table Name, Status, StartType
```

---

## 🗑️ Uninstall Services

```powershell
# As Administrator
.\install-as-services.ps1 -Uninstall
```

This will:
1. Stop both services
2. Remove them from Windows Services
3. Clean up completely

---

## 🧪 Test the Services

```powershell
# Send test order
curl http://localhost:8081/api/order/test

# Check status
curl http://localhost:8082/api/status/health

# Or open in browser
start http://localhost:8081/swagger
start http://localhost:8082/swagger
```

---

## 📊 Comparison: Console vs Services

| Feature | Console Apps | Windows Services |
|---------|--------------|------------------|
| **Visibility** | Windows with logs | Background |
| **Logs** | Console output | Windows Event Log |
| **Startup** | Manual | Automatic |
| **Debugging** | Easy to see | Need Event Viewer |
| **Production** | ❌ No | ✅ Yes |
| **Demo** | ✅ Yes | ✅ Yes |

---

## 📝 View Service Logs

Services write to Windows Event Viewer:

```powershell
# Open Event Viewer
eventvwr.msc

# Navigate to: Windows Logs → Application
# Filter by source: .NET Runtime or your app name
```

Or via PowerShell:
```powershell
Get-EventLog -LogName Application -Source ".NET Runtime" -Newest 50
```

---

## 🐕 Datadog with Services

Datadog instrumentation works **exactly the same** with Windows Services!

### Set Environment Variables for Service

You need to set them **system-wide** or **per-service**:

```powershell
# Option 1: Set system-wide (affects all .NET services)
[System.Environment]::SetEnvironmentVariable("CORECLR_ENABLE_PROFILING", "1", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("CORECLR_PROFILER", "{846F5F1C-F9AE-4B07-969E-05C26BC060D8}", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("CORECLR_PROFILER_PATH", "C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("DD_DOTNET_TRACER_HOME", "C:\Program Files\Datadog\.NET Tracer", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("DD_ENV", "production", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("DD_SERVICE", "iis-msmq-demo", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("DD_TRACE_MSMQ_ENABLED", "true", [System.EnvironmentVariableTarget]::Machine)

# Restart services to pick up new env vars
Restart-Service MsmqSenderService, MsmqReceiverService
```

---

## 🔧 Troubleshooting

### Service Won't Start

```powershell
# Check service status
Get-Service MsmqSenderService | Format-List *

# Check Event Viewer for errors
Get-EventLog -LogName Application -Newest 10 | Where-Object {$_.Source -like "*.NET*"}
```

### Port Already in Use

```powershell
# Find what's using the port
netstat -ano | findstr "8081"

# Stop that process or change port in appsettings.json
# Then rebuild and reinstall service
```

### Service Crashes on Startup

Common causes:
1. **MSMQ not installed** - Run `.\setup-msmq.ps1`
2. **Permissions** - Service needs access to MSMQ
3. **Missing dependencies** - Ensure all DLLs are in bin folder

Fix:
```powershell
# Check MSMQ
Get-Service MSMQ

# Rebuild
dotnet clean
dotnet build -c Release

# Reinstall
.\install-as-services.ps1 -Uninstall
.\install-as-services.ps1
```

---

## 🎯 When to Use Services vs Console Apps

### Use **Windows Services** when:
- ✅ Production or production-like environment
- ✅ Need automatic startup on boot
- ✅ Want apps running 24/7
- ✅ Demonstrating enterprise deployment
- ✅ Running on server without interactive login

### Use **Console Apps** when:
- ✅ Development and testing
- ✅ Need to see logs in real-time
- ✅ Debugging issues
- ✅ Quick demos where you want to show logs
- ✅ Easier to start/stop

---

## 📋 Service Details

### Sender Service
- **Name**: MsmqSenderService
- **Display Name**: MSMQ Sender Service
- **Description**: IIS MSMQ Demo - Sender Application (Port 8081)
- **Startup Type**: Automatic
- **Binary**: `SenderWebApp\bin\Release\net8.0\SenderWebApp.exe`

### Receiver Service
- **Name**: MsmqReceiverService
- **Display Name**: MSMQ Receiver Service
- **Description**: IIS MSMQ Demo - Receiver Application (Port 8082)
- **Startup Type**: Automatic
- **Binary**: `ReceiverWebApp\bin\Release\net8.0\ReceiverWebApp.exe`

---

## 🔄 Update Services

After code changes:

```powershell
# 1. Stop services
Stop-Service MsmqSenderService, MsmqReceiverService

# 2. Rebuild
dotnet build -c Release

# 3. Start services
Start-Service MsmqSenderService, MsmqReceiverService
```

Or reinstall:
```powershell
.\install-as-services.ps1 -Uninstall
.\install-as-services.ps1
```

---

## 💡 Pro Tips

1. **View Services GUI**: Press `Win + R`, type `services.msc`
2. **Set Recovery Options**: In services.msc, right-click service → Properties → Recovery tab
3. **Delay Start**: Useful if Receiver needs Sender's queue created first
4. **Log to File**: Add file logging in `Program.cs` for easier debugging

---

## 📖 Summary

```powershell
# Install
.\install-as-services.ps1

# Test
curl http://localhost:8081/api/order/test

# Manage
Get-Service Msmq*
Stop-Service MsmqSenderService
Start-Service MsmqSenderService

# Uninstall
.\install-as-services.ps1 -Uninstall
```

**Windows Services = Production-Ready! 🚀**

