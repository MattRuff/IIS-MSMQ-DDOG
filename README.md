# IIS MSMQ Distributed Tracing Demo

This project demonstrates Datadog's **automatic instrumentation** for ASP.NET Web API 2 applications with MSMQ (Microsoft Message Queue). It shows what can be traced automatically without code changes, and documents the limitations of auto-instrumentation for background workers.

## Architecture

```
┌─────────────────┐      MSMQ Queue       ┌─────────────────┐
│  Sender App     │ ───────────────────►  │  Receiver App   │
│  (Port 8081)    │   OrderQueue          │  (Port 8082)    │
│  Web API 2      │                       │  Web API 2      │
└─────────────────┘                       └─────────────────┘
     ✅ Traced                                  ⚠️ HTTP only
```

### Flow
1. **Sender App**: Receives HTTP requests and publishes messages to MSMQ
   - ✅ HTTP endpoints automatically traced by Datadog
   - ✅ MSMQ send operations automatically traced (`MessageQueue.Send()`)
2. **MSMQ Queue**: Message broker (`.\private$\OrderQueue`)
3. **Receiver App**: Background timer polls MSMQ using synchronous `Receive()`
   - ✅ HTTP endpoints automatically traced
   - ⚠️ Background MSMQ receive (`MessageQueue.Receive()`) uses auto-instrumented library
   - ❌ Background worker context may not generate traces (no HTTP parent span)

## Prerequisites

### Required
- **Windows OS** (Windows 10/11 or Windows Server 2016+)
- **.NET Framework 4.8 Developer Pack** ([Download](https://dotnet.microsoft.com/download/dotnet-framework/net48))
- **.NET SDK** (for building) ([Download](https://dotnet.microsoft.com/download))
- **PowerShell 5.1** or later (included with Windows)
- **Administrator privileges** (for MSMQ installation)

> **🍎 Mac Users**: MSMQ requires Windows. See [MAC-USERS.md](MAC-USERS.md) for running in a Windows VM.

### Optional (for Datadog tracing)
- **Datadog account** with APM enabled
- **Datadog Agent** installed on Windows

## Quick Start

### Step 1: Install MSMQ

Run the setup script as Administrator:

```powershell
# Right-click PowerShell and select "Run as Administrator"
cd "path\to\IIS MSMQ"
.\setup-msmq.ps1
```

> **Note**: If MSMQ installation requires a restart, restart your computer and continue to Step 2.

### Step 2: Build the Solution

```powershell
# Restore dependencies
dotnet restore

# Build the solution
dotnet build
```

### Step 3: Run the Applications

Use the provided script to start both applications:

```powershell
.\run-applications.ps1
```

This will open two PowerShell windows:
- **Sender App**: http://localhost:8081
- **Receiver App**: http://localhost:8082

### Step 4: Test the System

In a new PowerShell window:

```powershell
.\test-system.ps1
```

Or manually test with curl:

```powershell
# Send a test order
curl http://localhost:8081/api/order/test

# Check sender health
curl http://localhost:8081/api/order/health

# Check receiver health and queue status
curl http://localhost:8082/api/status/health
```

## API Endpoints

### Sender Application (Port 8081)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check |
| GET | `/swagger` | Swagger UI |
| POST | `/api/order` | Send custom order |
| GET | `/api/order/test` | Send test order |
| GET | `/api/order/health` | Check app and queue health |

#### Send Custom Order Example

```powershell
$body = @{
    customerName = "John Doe"
    productName = "Premium Widget"
    quantity = 5
    totalAmount = 299.99
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:8081/api/order" -Method Post -Body $body -ContentType "application/json"
```

### Receiver Application (Port 8082)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Health check |
| GET | `/swagger` | Swagger UI |
| GET | `/api/status/health` | Check app, queue health, and message count |
| GET | `/api/status/queue-status` | Get detailed queue status |

## Datadog Integration

### Method 1: Single-Step Instrumentation (Recommended)

This is the easiest method and requires no code changes.

#### For Development/Testing (Console Apps)

1. **Download the Datadog .NET Tracer**

```powershell
# Create a directory for Datadog
mkdir C:\datadog
cd C:\datadog

# Download the MSI installer
# Visit: https://github.com/DataDog/dd-trace-dotnet/releases
# Download: datadog-dotnet-apm-<version>-x64.msi

# Or use direct download (replace with latest version)
Invoke-WebRequest -Uri "https://github.com/DataDog/dd-trace-dotnet/releases/latest/download/datadog-dotnet-apm-2.x.x-x64.msi" -OutFile "datadog-apm.msi"

# Install
msiexec /i datadog-apm.msi /quiet
```

2. **Set Environment Variables**

Before running the applications, set these environment variables:

```powershell
# Required for auto-instrumentation
$env:CORECLR_ENABLE_PROFILING=1
$env:CORECLR_PROFILER="{846F5F1C-F9AE-4B07-969E-05C26BC060D8}"
$env:CORECLR_PROFILER_PATH="C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll"
$env:DD_DOTNET_TRACER_HOME="C:\Program Files\Datadog\.NET Tracer"

# Datadog configuration
$env:DD_API_KEY="your-api-key-here"
$env:DD_SITE="datadoghq.com"  # or datadoghq.eu, us3.datadoghq.com, etc.
$env:DD_ENV="sandbox"
$env:DD_SERVICE="iis-msmq-demo"
$env:DD_VERSION="1.0.0"

# Enable MSMQ instrumentation
$env:DD_TRACE_MSMQ_ENABLED=true

# Then run the applications
cd SenderWebApp
dotnet run
```

3. **Alternative: Modify PowerShell Scripts**

Edit `run-applications.ps1` to include environment variables:

```powershell
# Add this before Start-Process commands
$env:CORECLR_ENABLE_PROFILING=1
$env:CORECLR_PROFILER="{846F5F1C-F9AE-4B07-969E-05C26BC060D8}"
$env:CORECLR_PROFILER_PATH="C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll"
$env:DD_DOTNET_TRACER_HOME="C:\Program Files\Datadog\.NET Tracer"
$env:DD_API_KEY="your-api-key-here"
$env:DD_ENV="sandbox"
$env:DD_SERVICE="iis-msmq-demo"
$env:DD_TRACE_MSMQ_ENABLED=true
```

#### For IIS Deployment

1. **Install Datadog .NET Tracer** (same MSI as above)

2. **Configure IIS Application Pool**

```powershell
# Import IIS module
Import-Module WebAdministration

# Set environment variables for the application pool
$appPoolName = "YourAppPoolName"

Set-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "Recycling.periodicRestart.time" -Value "00:00:00"

# Set environment variables
$envVars = @{
    "CORECLR_ENABLE_PROFILING" = "1"
    "CORECLR_PROFILER" = "{846F5F1C-F9AE-4B07-969E-05C26BC060D8}"
    "CORECLR_PROFILER_PATH" = "C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll"
    "DD_DOTNET_TRACER_HOME" = "C:\Program Files\Datadog\.NET Tracer"
    "DD_API_KEY" = "your-api-key-here"
    "DD_ENV" = "production"
    "DD_SERVICE" = "iis-msmq-demo"
    "DD_TRACE_MSMQ_ENABLED" = "true"
}

foreach ($key in $envVars.Keys) {
    $envVar = New-Object Microsoft.Web.Administration.ConfigurationElement
    $envVar = $envVars[$key]
    
    # This will vary based on your IIS version
    # Use IIS Manager GUI to set environment variables for simplicity
}

# Restart the app pool
Restart-WebAppPool -Name $appPoolName
```

Or use the IIS Manager GUI:
1. Open IIS Manager
2. Select your Application Pool
3. Advanced Settings → Environment Variables
4. Add the variables listed above

3. **Restart IIS**

```powershell
iisreset
```

### Method 2: Manual Instrumentation (Alternative)

If you prefer explicit control or need custom spans:

1. **Add NuGet Package**

```powershell
dotnet add package Datadog.Trace
```

2. **Add Tracer Configuration** in `Program.cs`:

```csharp
using Datadog.Trace;
using Datadog.Trace.Configuration;

// Configure Datadog
var settings = TracerSettings.FromDefaultSources();
settings.Environment = "sandbox";
settings.ServiceName = "iis-msmq-sender"; // or "iis-msmq-receiver"
settings.ServiceVersion = "1.0.0";

Tracer.Configure(settings);
```

3. **Create Custom Spans** (optional):

```csharp
using Datadog.Trace;

public void SendMessage(OrderMessage message)
{
    using (var scope = Tracer.Instance.StartActive("msmq.send"))
    {
        scope.Span.SetTag("order.id", message.OrderId);
        scope.Span.SetTag("customer.name", message.CustomerName);
        
        // Your MSMQ send logic
    }
}
```

## Viewing Traces in Datadog

1. Log in to your Datadog account
2. Navigate to **APM → Traces**
3. You should see traces with service names:
   - `SenderWebApp`
   - `ReceiverWebApp`

## ⚠️ Auto-Instrumentation Limitations

This project uses **Datadog's automatic instrumentation** for ASP.NET Web API 2 applications. Understanding what is and isn't automatically traced is important for setting expectations.

### ✅ What IS Auto-Instrumented

According to [Datadog's .NET Framework compatibility documentation](https://docs.datadoghq.com/tracing/trace_collection/compatibility/dotnet-framework/#integrations):

| Component | Status | Integration Name |
|-----------|--------|------------------|
| **ASP.NET Web API 2 HTTP Endpoints** | ✅ Automatic | `AspNetWebApi2` |
| **MSMQ Send Operations** | ✅ Automatic | `Msmq` (built-in) |
| **MSMQ Receive Operations** | ✅ Automatic* | `Msmq` (built-in) |

\* *Only when called within an HTTP request context*

### ❌ What Is NOT Auto-Instrumented

| Component | Status | Reason |
|-----------|--------|--------|
| **Background Services** | ❌ Not Traced | No HTTP context |
| **Timer-based Workers** | ❌ Not Traced | Runs outside HTTP request/response flow |
| **Synchronous MSMQ Receive in Background** | ⚠️ **Testing** | Uses `MessageQueue.Receive()` (auto-instrumented), but runs in background Timer (no HTTP parent) |
| **Message Processing Logic** | ❌ Not Traced | Happens in background `Timer`, not HTTP handler |

### 📊 What You'll Actually See

When you send a test order via `GET /api/order/test`, Datadog will trace:

```
HTTP GET /api/order/test (SenderWebApp) ← Traced automatically
  └─ msmq.send .\private$\OrderQueue   ← Traced automatically
```

**You MAY or MAY NOT see:**
```
⚠️ msmq.receive (ReceiverWebApp)       ← Uses auto-instrumented MessageQueue.Receive()
                                         but runs in background Timer without HTTP context
❌ process.order                        ← Not traced (background worker)
```

### Why This Happens

1. **MSMQ Send is traced** because it happens **during the HTTP request** to `/api/order/test`
2. **MSMQ Receive might not be traced** because:
   - The `ReceiverWebApp` uses a background `Timer` to poll MSMQ
   - Background workers run **outside HTTP request contexts**
   - While `MessageQueue.Receive()` itself is auto-instrumented, Datadog may not create traces for operations without a parent HTTP span
   - This is an **experiment** to see if synchronous `Receive()` generates standalone traces

### ✅ Workaround: Generate HTTP Traffic to Receiver

While MSMQ receive operations in background workers aren't traced, you **can** see the ReceiverWebApp in Datadog by hitting its HTTP endpoints:

```powershell
# Generate HTTP traces for ReceiverWebApp
curl http://localhost:8082/api/status/health
curl http://localhost:8082/api/status/queue-status
```

This will show the ReceiverWebApp service in Datadog APM with HTTP request traces.

### 🔧 For Full Distributed Tracing

To achieve **complete end-to-end tracing** from Sender → MSMQ → Receiver, you would need:

1. **Manual instrumentation** using the `Datadog.Trace` NuGet package
2. **Trace context propagation** through MSMQ message payloads
3. **Custom spans** for background worker operations

This requires code changes and is beyond the scope of this **auto-instrumentation demo**.

### 📖 Key Takeaway

This demo shows **what Datadog can trace automatically** without code changes:
- ✅ ASP.NET Web API 2 HTTP endpoints
- ✅ MSMQ operations within HTTP contexts
- ❌ Background workers require manual instrumentation

This is a **realistic limitation** of automatic instrumentation and represents a common pattern in distributed systems where message processing happens asynchronously in background services.

## Troubleshooting

### MSMQ Issues

**Queue not found:**
```powershell
# Verify MSMQ is running
Get-Service MSMQ

# Start MSMQ if needed
Start-Service MSMQ

# Check if queue exists
[System.Messaging.MessageQueue]::Exists(".\private$\OrderQueue")
```

**Create queue manually:**
```powershell
[System.Messaging.MessageQueue]::Create(".\private$\OrderQueue")
```

**View queues in Computer Management:**
1. Press `Win + X` → Computer Management
2. Expand "Services and Applications" → Message Queuing → Private Queues
3. You should see `OrderQueue`

### Application Issues

**Port already in use:**
- Change the port in `appsettings.json` under `"Urls"`

**Sender can't connect to queue:**
- Ensure MSMQ service is running
- Check firewall settings
- Verify queue path in `appsettings.json`

**Receiver not processing messages:**
- Check receiver application logs
- Verify the background service is running
- Ensure queue path matches in both apps

### Datadog Issues

**No traces appearing:**
1. Verify Datadog Agent is running:
   ```powershell
   Get-Service datadogagent
   ```

2. Check environment variables are set correctly

3. Enable debug logging:
   ```powershell
   $env:DD_TRACE_DEBUG=true
   ```

4. Check Datadog Agent logs:
   - `C:\ProgramData\Datadog\logs\agent.log`

5. Verify MSMQ instrumentation is enabled:
   ```powershell
   $env:DD_TRACE_MSMQ_ENABLED=true
   ```

**Distributed trace not connecting:**
- Ensure both applications have the same `DD_ENV` setting
- Verify trace context is being propagated through MSMQ messages
- Check that both apps are using compatible Datadog tracer versions

## Project Structure

```
IIS-MSMQ-Demo/
├── SenderWebApp/              # Message sender application
│   ├── Controllers/
│   │   └── OrderController.cs # REST API endpoints
│   ├── Models/
│   │   └── OrderMessage.cs    # Message model
│   ├── Services/
│   │   ├── IMsmqService.cs    # Interface
│   │   └── MsmqService.cs     # MSMQ sender implementation
│   ├── Program.cs             # Application entry point
│   ├── appsettings.json       # Configuration
│   └── SenderWebApp.csproj
│
├── ReceiverWebApp/            # Message receiver application
│   ├── Controllers/
│   │   └── StatusController.cs # Status endpoints
│   ├── Models/
│   │   └── OrderMessage.cs    # Message model
│   ├── Services/
│   │   ├── IMsmqReceiverService.cs        # Interface
│   │   ├── MsmqReceiverService.cs         # MSMQ receiver implementation
│   │   └── MessageProcessorService.cs     # Background service
│   ├── Program.cs             # Application entry point
│   ├── appsettings.json       # Configuration
│   └── ReceiverWebApp.csproj
│
├── setup-msmq.ps1            # MSMQ installation script
├── run-applications.ps1      # Start both applications
├── test-system.ps1           # Test script
├── IIS-MSMQ-Demo.sln        # Visual Studio solution
├── .gitignore
└── README.md                 # This file
```

## Configuration

### Queue Configuration

Both applications use the same queue path, configurable in `appsettings.json`:

```json
{
  "MSMQ": {
    "QueuePath": ".\\private$\\OrderQueue"
  }
}
```

### Port Configuration

Change ports in respective `appsettings.json`:

```json
{
  "Urls": "http://localhost:8081"  // or 5002 for receiver
}
```

## Development Notes

### Message Format

Messages are serialized as JSON and sent through MSMQ:

```json
{
  "orderId": "guid",
  "customerName": "string",
  "productName": "string",
  "quantity": 0,
  "totalAmount": 0.0,
  "orderDate": "2024-01-01T00:00:00Z",
  "status": "Pending"
}
```

### Extending the Demo

To extend this demo:

1. **Add more message types**: Create additional models in the `Models` folder
2. **Add business logic**: Modify `MessageProcessorService.ProcessOrder()`
3. **Add persistence**: Integrate Entity Framework or another ORM
4. **Add multiple queues**: Configure different queues for different message types
5. **Add error handling**: Implement dead-letter queues for failed messages

## Resources

- [MSMQ Documentation](https://docs.microsoft.com/en-us/dotnet/api/system.messaging)
- [Datadog .NET APM](https://docs.datadoghq.com/tracing/setup_overview/setup/dotnet-core/)
- [Datadog MSMQ Integration](https://docs.datadoghq.com/integrations/msmq/)
- [ASP.NET Core Documentation](https://docs.microsoft.com/en-us/aspnet/core/)

## License

This is a demo project for learning and testing purposes.

## Support

For issues or questions:
- Check the Troubleshooting section above
- Review Datadog documentation
- Check application logs for error messages

