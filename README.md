# IIS MSMQ Distributed Tracing Demo

This project demonstrates a distributed tracing scenario using .NET IIS applications communicating via MSMQ (Microsoft Message Queue), ready for Datadog APM instrumentation.

## Architecture

```
┌─────────────────┐      MSMQ Queue       ┌─────────────────┐
│  Sender App     │ ───────────────────►  │  Receiver App   │
│  (Port 5001)    │   OrderQueue          │  (Port 5002)    │
│  IIS Web API    │                       │  IIS Web API    │
└─────────────────┘                       └─────────────────┘
```

### Flow
1. **Sender App**: Receives HTTP POST requests and publishes messages to MSMQ
2. **MSMQ Queue**: Message broker (.\private$\OrderQueue)
3. **Receiver App**: Background service continuously polls MSMQ and processes messages

## Prerequisites

### Required
- **Windows OS** (Windows 10/11 or Windows Server 2016+)
- **.NET 8.0 SDK** or later ([Download](https://dotnet.microsoft.com/download/dotnet/8.0))
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
- **Sender App**: http://localhost:5001
- **Receiver App**: http://localhost:5002

### Step 4: Test the System

In a new PowerShell window:

```powershell
.\test-system.ps1
```

Or manually test with curl:

```powershell
# Send a test order
curl http://localhost:5001/api/order/test

# Check sender health
curl http://localhost:5001/api/order/health

# Check receiver health and queue status
curl http://localhost:5002/api/status/health
```

## API Endpoints

### Sender Application (Port 5001)

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

Invoke-RestMethod -Uri "http://localhost:5001/api/order" -Method Post -Body $body -ContentType "application/json"
```

### Receiver Application (Port 5002)

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
   - `iis-msmq-demo` (or your custom service name)
4. The distributed trace will show:
   - HTTP request to Sender App
   - MSMQ message send operation
   - MSMQ message receive operation
   - Message processing in Receiver App

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
  "Urls": "http://localhost:5001"  // or 5002 for receiver
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

