# Project Structure & Organization

## 📁 Directory Structure

```
IIS-MSMQ-DDOG/
├── SenderWebApp/              # HTTP API → MSMQ Sender
│   ├── Controllers/          # API endpoints
│   ├── Services/            # MSMQ service implementations
│   ├── Models/              # Data models
│   ├── Program.cs           # Application entry point
│   └── appsettings.json     # Configuration (Port 8081)
│
├── ReceiverWebApp/           # MSMQ → Background Processor
│   ├── Controllers/         # Status endpoints
│   ├── Services/           # MSMQ receiver & processor
│   ├── Models/             # Data models
│   ├── Program.cs          # Application entry point
│   └── appsettings.json    # Configuration (Port 8082)
│
├── *.ps1                    # PowerShell automation scripts
└── *.md                     # Documentation files
```

---

## 🚀 PowerShell Scripts

### Core Scripts
| Script | Purpose | When to Use |
|--------|---------|-------------|
| `install-as-services.ps1` | Install/uninstall Windows Services | **Production deployment** |
| `run-applications.ps1` | Run as console apps (dev mode) | Development/testing |
| `validate-tracing.ps1` | Test distributed tracing with 14 requests | **Validation after Datadog setup** |
| `test-system.ps1` | Quick end-to-end system test | Quick health check |
| `setup-msmq.ps1` | Install MSMQ feature on Windows | **First-time setup** |
| `build-and-run.ps1` | Complete setup: MSMQ + build + run | All-in-one script |

### Script Usage

**Windows Service (Production):**
```powershell
.\install-as-services.ps1          # Install & start
.\install-as-services.ps1 -Uninstall  # Uninstall & cleanup
```

**Console Mode (Development):**
```powershell
.\run-applications.ps1             # Run both apps in separate windows
```

**Testing:**
```powershell
.\test-system.ps1                  # Quick system test
.\validate-tracing.ps1             # Full Datadog validation
```

---

## 📚 Documentation Files

### Quick Start Guides
- **`START-HERE.md`** - Main entry point with navigation
- **`QUICK-START.md`** - 5-minute quick start (Windows)
- **`WINDOWS-QUICK-START.md`** - Windows-specific quickstart
- **`WINDOWS-SERVICES.md`** - Windows Service deployment guide

### Platform-Specific
- **`MAC-USERS.md`** - Guide for Mac users (using Windows VM)
- **`MOCK-VS-REAL-MSMQ.md`** - Switching between mock and real MSMQ

### Technical Documentation
- **`ARCHITECTURE.md`** - System architecture deep dive
- **`DATADOG-SETUP.md`** - Datadog instrumentation guide
- **`ERROR-LOGGING-EXAMPLE.md`** - Error logging with Datadog fields
- **`SAMPLE-REQUESTS.md`** - API examples and test scenarios
- **`VALIDATION-REPORT.md`** - System validation results

### GitHub
- **`README.md`** - Main README for GitHub
- **`GITHUB-README.md`** - GitHub-optimized README

---

## 🔧 Configuration

### Ports
- **Sender**: `8081` (HTTP API)
- **Receiver**: `8082` (Background processor with status endpoint)

### MSMQ Queue
- **Path**: `.\private$\OrderQueue`
- **Type**: Private transactional queue
- **Created by**: Sender app on first run

### Logging
- **Format**: JSON (CompactJsonFormatter)
- **Location**: `{app}/logs/{app}-.json`
- **Retention**: 7 days, daily rolling
- **Fields**: Includes `dd.service`, `dd.version`, `dd.env`, error fields

---

## 🏗️ Build Configuration

### Target Framework
- **.NET 8.0** (`net8.0`)

### Platform Requirements
- **Mac/Linux**: Builds with mock MSMQ services
- **Windows**: Builds with real MSMQ (`Experimental.System.Messaging`)

### Conditional Compilation
The `Experimental.System.Messaging` package is only included on Windows:

```xml
<PackageReference Include="Experimental.System.Messaging" 
                  Version="1.1.0" 
                  Condition="'$(OS)' == 'Windows_NT'" />
```

### Build Commands

**On Mac (development):**
```bash
dotnet restore
dotnet build  # Uses mock MSMQ services
```

**On Windows (production):**
```powershell
dotnet restore
dotnet build -c Release  # Uses real MSMQ
```

---

## 🔐 Service Accounts

### Windows Services
- **Account**: `LocalSystem`
- **Privileges**: `SeChangeNotifyPrivilege`, `SeImpersonatePrivilege`, `SeCreateGlobalPrivilege`
- **MSMQ Access**: Full access to private queues

---

## 📊 Datadog Integration

### Environment Variables
```powershell
$env:DD_ENV = "production"
$env:DD_SERVICE = "SenderWebApp"  # or "ReceiverWebApp"
$env:DD_VERSION = "{git-sha}"     # Auto-set at build time
```

### Automatic Tagging
All logs and traces include:
- `dd.service` - Service name
- `dd.version` - Git commit SHA
- `dd.env` - Environment (from `DD_ENV`)
- `version` - Git commit SHA
- `service` - Service name

### Error Fields
All exceptions automatically include:
- `error.message` - Exception message
- `error.type` - Exception type
- `error.stack` - Stack trace
- `error.handling` - "handled" or "unhandled"

---

## 🧪 Testing Endpoints

### Sender (Port 8081)
```bash
# Health check
curl http://localhost:8081/

# Test order
curl http://localhost:8081/api/order/test

# Custom order
curl -X POST http://localhost:8081/api/order \
  -H "Content-Type: application/json" \
  -d '{"orderId":"123","customerName":"John","productName":"Widget","quantity":5,"price":29.99}'

# Swagger UI
http://localhost:8081/swagger
```

### Receiver (Port 8082)
```bash
# Health check
curl http://localhost:8082/

# Service health
curl http://localhost:8082/api/status/health

# Queue status
curl http://localhost:8082/api/status/queue-status

# Swagger UI
http://localhost:8082/swagger
```

---

## 🗑️ Cleaned Up Items

### Removed Build Artifacts
- ❌ Old `Debug/net6.0` folders
- ❌ All `Debug` build configurations
- ✅ Only `Release/net8.0` builds kept

### Fixed Port References
- ✅ Updated all scripts from `5001/5002` to `8081/8082`
- ✅ Updated all documentation
- ✅ Updated Postman collection

### File Logging
- ✅ Fixed log paths to use absolute paths (Windows Service compatible)
- ✅ Logs created in application directory, not System32

---

## 📖 Documentation Best Practices

### For Quick Setup
1. Start with **`START-HERE.md`**
2. Follow **`WINDOWS-QUICK-START.md`**
3. Use **`install-as-services.ps1`**
4. Validate with **`validate-tracing.ps1`**

### For Troubleshooting
1. Check **`WINDOWS-SERVICES.md`** for service issues
2. Check **`ERROR-LOGGING-EXAMPLE.md`** for log examples
3. Check application logs in `{app}/bin/Release/net8.0/logs/`

### For Development
1. See **`ARCHITECTURE.md`** for system design
2. See **`SAMPLE-REQUESTS.md`** for API examples
3. Use **`run-applications.ps1`** for console mode

---

## ✅ System Health Checklist

```powershell
# 1. Check services
Get-Service MsmqSenderService, MsmqReceiverService

# 2. Check queue
Get-MsmqQueue -Name "OrderQueue" -QueueType Private

# 3. Check logs
Get-ChildItem ReceiverWebApp\bin\Release\net8.0\logs

# 4. Send test order
curl http://localhost:8081/api/order/test

# 5. Check processing
curl http://localhost:8082/api/status/health

# 6. Verify tracing
.\validate-tracing.ps1
```

---

## 🎯 Key Files for Deployment

**Minimum files needed on Windows VM:**
1. `SenderWebApp/` directory
2. `ReceiverWebApp/` directory
3. `IIS-MSMQ-Demo.sln`
4. `install-as-services.ps1`
5. `setup-msmq.ps1`
6. `.gitignore`

**Everything else is documentation or helper scripts.**

---

## 🚦 Deployment Workflow

```
1. Fresh Windows VM
   ↓
2. Run: setup-msmq.ps1 (as Admin)
   ↓
3. Clone/copy code
   ↓
4. Run: dotnet restore
   ↓
5. Run: dotnet build -c Release
   ↓
6. Run: install-as-services.ps1
   ↓
7. Install Datadog tracer (optional)
   ↓
8. Test: validate-tracing.ps1
```

---

**Project cleaned and organized! ✅**

