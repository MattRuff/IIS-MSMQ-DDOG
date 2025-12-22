# Datadog Single-Step Instrumentation Guide for IIS MSMQ Demo

This guide provides detailed instructions for instrumenting the IIS MSMQ demo with Datadog APM using single-step instrumentation.

## Prerequisites

- Windows machine with the IIS MSMQ demo installed
- Datadog account with APM enabled
- Datadog API key ([Get one here](https://app.datadoghq.com/organization-settings/api-keys))
- Administrator privileges

## Step 1: Install Datadog Agent

### Download and Install

1. **Download the Datadog Agent installer**:
   - Visit [Datadog Agent Download Page](https://app.datadoghq.com/account/settings/agent/latest?platform=windows)
   - Or use PowerShell:

```powershell
# Download the latest agent
$url = "https://s3.amazonaws.com/ddagent-windows-stable/datadog-agent-7-latest.amd64.msi"
$output = "$env:TEMP\datadog-agent.msi"
Invoke-WebRequest -Uri $url -OutFile $output
```

2. **Install the agent**:

```powershell
# Replace YOUR_API_KEY with your actual Datadog API key
msiexec /i "$env:TEMP\datadog-agent.msi" /quiet APIKEY="YOUR_API_KEY" SITE="datadoghq.com"
```

> **Note**: Replace `datadoghq.com` with your Datadog site:
> - US1: `datadoghq.com`
> - EU: `datadoghq.eu`
> - US3: `us3.datadoghq.com`
> - US5: `us5.datadoghq.com`
> - US1-FED: `ddog-gov.com`

3. **Verify the agent is running**:

```powershell
Get-Service datadogagent
# Should show "Running"
```

4. **Enable APM**:

Edit `C:\ProgramData\Datadog\datadog.yaml`:

```yaml
# APM Configuration
apm_config:
  enabled: true
  apm_non_local_traffic: false
```

Restart the agent:

```powershell
Restart-Service datadogagent
```

## Step 2: Install .NET Tracer

### Download and Install

1. **Download the .NET Tracer MSI**:

```powershell
# Create directory
New-Item -ItemType Directory -Force -Path C:\Datadog

# Download (replace version with latest)
$tracerVersion = "2.49.0"  # Check latest at https://github.com/DataDog/dd-trace-dotnet/releases
$url = "https://github.com/DataDog/dd-trace-dotnet/releases/download/v$tracerVersion/datadog-dotnet-apm-$tracerVersion-x64.msi"
$output = "C:\Datadog\datadog-dotnet-apm.msi"

Invoke-WebRequest -Uri $url -OutFile $output
```

2. **Install the tracer**:

```powershell
msiexec /i "C:\Datadog\datadog-dotnet-apm.msi" /quiet
```

3. **Verify installation**:

```powershell
Test-Path "C:\Program Files\Datadog\.NET Tracer"
# Should return True
```

## Step 3: Configure for Development (dotnet run)

For running the applications with `dotnet run` or the provided PowerShell scripts:

### Option A: Set System-Wide Environment Variables

```powershell
# Run as Administrator
[System.Environment]::SetEnvironmentVariable("CORECLR_ENABLE_PROFILING", "1", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("CORECLR_PROFILER", "{846F5F1C-F9AE-4B07-969E-05C26BC060D8}", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("CORECLR_PROFILER_PATH", "C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("DD_DOTNET_TRACER_HOME", "C:\Program Files\Datadog\.NET Tracer", [System.EnvironmentVariableTarget]::Machine)

# Datadog configuration
[System.Environment]::SetEnvironmentVariable("DD_ENV", "sandbox", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("DD_SERVICE", "iis-msmq-demo", [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("DD_VERSION", "1.0.0", [System.EnvironmentVariableTarget]::Machine)

# Enable MSMQ instrumentation
[System.Environment]::SetEnvironmentVariable("DD_TRACE_MSMQ_ENABLED", "true", [System.EnvironmentVariableTarget]::Machine)

# IMPORTANT: Restart your terminal/PowerShell after setting machine-level variables
```

### Option B: Modified Run Script

Create a new file `run-applications-with-datadog.ps1`:

```powershell
# Set environment variables for this session
$env:CORECLR_ENABLE_PROFILING = "1"
$env:CORECLR_PROFILER = "{846F5F1C-F9AE-4B07-969E-05C26BC060D8}"
$env:CORECLR_PROFILER_PATH = "C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll"
$env:DD_DOTNET_TRACER_HOME = "C:\Program Files\Datadog\.NET Tracer"

# Datadog configuration
$env:DD_ENV = "sandbox"
$env:DD_SERVICE = "iis-msmq-demo"
$env:DD_VERSION = "1.0.0"
$env:DD_TRACE_MSMQ_ENABLED = "true"

# Optional: Enable debug logging
# $env:DD_TRACE_DEBUG = "true"
# $env:DD_TRACE_LOG_DIRECTORY = "C:\logs\datadog"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting IIS MSMQ Demo with Datadog APM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Start Sender Application
Write-Host "Starting Sender Web App with Datadog instrumentation..." -ForegroundColor Yellow

$senderScript = @"
`$env:CORECLR_ENABLE_PROFILING = '1'
`$env:CORECLR_PROFILER = '{846F5F1C-F9AE-4B07-969E-05C26BC060D8}'
`$env:CORECLR_PROFILER_PATH = 'C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll'
`$env:DD_DOTNET_TRACER_HOME = 'C:\Program Files\Datadog\.NET Tracer'
`$env:DD_ENV = 'sandbox'
`$env:DD_SERVICE = 'msmq-sender'
`$env:DD_VERSION = '1.0.0'
`$env:DD_TRACE_MSMQ_ENABLED = 'true'

cd '$scriptPath\SenderWebApp'
dotnet run
"@

Start-Process powershell -ArgumentList "-NoExit", "-Command", $senderScript

Start-Sleep -Seconds 2

# Start Receiver Application
Write-Host "Starting Receiver Web App with Datadog instrumentation..." -ForegroundColor Yellow

$receiverScript = @"
`$env:CORECLR_ENABLE_PROFILING = '1'
`$env:CORECLR_PROFILER = '{846F5F1C-F9AE-4B07-969E-05C26BC060D8}'
`$env:CORECLR_PROFILER_PATH = 'C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll'
`$env:DD_DOTNET_TRACER_HOME = 'C:\Program Files\Datadog\.NET Tracer'
`$env:DD_ENV = 'sandbox'
`$env:DD_SERVICE = 'msmq-receiver'
`$env:DD_VERSION = '1.0.0'
`$env:DD_TRACE_MSMQ_ENABLED = 'true'

cd '$scriptPath\ReceiverWebApp'
dotnet run
"@

Start-Process powershell -ArgumentList "-NoExit", "-Command", $receiverScript

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Applications Starting with Datadog APM!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Applications:" -ForegroundColor Yellow
Write-Host "  Sender:   http://localhost:8081" -ForegroundColor White
Write-Host "  Receiver: http://localhost:8082" -ForegroundColor White
Write-Host ""
Write-Host "Datadog:" -ForegroundColor Yellow
Write-Host "  Environment: sandbox" -ForegroundColor White
Write-Host "  Service: msmq-sender, msmq-receiver" -ForegroundColor White
Write-Host "  MSMQ Tracing: Enabled" -ForegroundColor White
Write-Host ""
Write-Host "View traces at: https://app.datadoghq.com/apm/traces" -ForegroundColor Cyan
Write-Host ""

Read-Host "Press Enter to exit"
```

### Run the Application

```powershell
.\run-applications-with-datadog.ps1
```

## Step 4: Configure for IIS Deployment

If you want to deploy to actual IIS:

### Publish the Applications

```powershell
# Publish Sender
dotnet publish SenderWebApp\SenderWebApp.csproj -c Release -o C:\inetpub\msmq-sender

# Publish Receiver
dotnet publish ReceiverWebApp\ReceiverWebApp.csproj -c Release -o C:\inetpub\msmq-receiver
```

### Create IIS Sites

```powershell
# Import IIS module
Import-Module WebAdministration

# Create Application Pools
New-WebAppPool -Name "MsmqSenderPool"
New-WebAppPool -Name "MsmqReceiverPool"

# Set .NET CLR version to "No Managed Code" (for .NET Core)
Set-ItemProperty "IIS:\AppPools\MsmqSenderPool" -Name "managedRuntimeVersion" -Value ""
Set-ItemProperty "IIS:\AppPools\MsmqReceiverPool" -Name "managedRuntimeVersion" -Value ""

# Create websites
New-Website -Name "MsmqSender" -Port 8001 -PhysicalPath "C:\inetpub\msmq-sender" -ApplicationPool "MsmqSenderPool"
New-Website -Name "MsmqReceiver" -Port 8002 -PhysicalPath "C:\inetpub\msmq-receiver" -ApplicationPool "MsmqReceiverPool"
```

### Configure Environment Variables for IIS

Create a script `configure-iis-datadog.ps1`:

```powershell
# Run as Administrator

Import-Module WebAdministration

function Set-AppPoolEnvironmentVariable {
    param(
        [string]$AppPoolName,
        [hashtable]$Variables
    )
    
    $appPoolPath = "IIS:\AppPools\$AppPoolName"
    
    foreach ($key in $Variables.Keys) {
        $value = $Variables[$key]
        
        # Set environment variable for app pool
        $envVars = Get-ItemProperty $appPoolPath -Name environmentVariables
        
        $newVar = @{
            name = $key
            value = $value
        }
        
        # Remove if exists
        $envVars = $envVars | Where-Object { $_.name -ne $key }
        
        # Add new
        $envVars += $newVar
        
        Set-ItemProperty $appPoolPath -Name environmentVariables -Value $envVars
    }
}

# Environment variables for both app pools
$datadogVars = @{
    "CORECLR_ENABLE_PROFILING" = "1"
    "CORECLR_PROFILER" = "{846F5F1C-F9AE-4B07-969E-05C26BC060D8}"
    "CORECLR_PROFILER_PATH" = "C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll"
    "DD_DOTNET_TRACER_HOME" = "C:\Program Files\Datadog\.NET Tracer"
    "DD_ENV" = "production"
    "DD_VERSION" = "1.0.0"
    "DD_TRACE_MSMQ_ENABLED" = "true"
}

# Sender-specific
$senderVars = $datadogVars.Clone()
$senderVars["DD_SERVICE"] = "msmq-sender"
Set-AppPoolEnvironmentVariable -AppPoolName "MsmqSenderPool" -Variables $senderVars

# Receiver-specific
$receiverVars = $datadogVars.Clone()
$receiverVars["DD_SERVICE"] = "msmq-receiver"
Set-AppPoolEnvironmentVariable -AppPoolName "MsmqReceiverPool" -Variables $receiverVars

# Restart app pools
Restart-WebAppPool -Name "MsmqSenderPool"
Restart-WebAppPool -Name "MsmqReceiverPool"

Write-Host "Datadog instrumentation configured for IIS!" -ForegroundColor Green
```

Run the script:

```powershell
.\configure-iis-datadog.ps1
```

### Alternative: Manual IIS Configuration

1. Open **IIS Manager**
2. Navigate to **Application Pools**
3. Select **MsmqSenderPool** → **Advanced Settings**
4. Find **Environment Variables** section
5. Add each variable:
   - Name: `CORECLR_ENABLE_PROFILING`, Value: `1`
   - Name: `CORECLR_PROFILER`, Value: `{846F5F1C-F9AE-4B07-969E-05C26BC060D8}`
   - Name: `CORECLR_PROFILER_PATH`, Value: `C:\Program Files\Datadog\.NET Tracer\win-x64\Datadog.Trace.ClrProfiler.Native.dll`
   - Name: `DD_DOTNET_TRACER_HOME`, Value: `C:\Program Files\Datadog\.NET Tracer`
   - Name: `DD_ENV`, Value: `production`
   - Name: `DD_SERVICE`, Value: `msmq-sender`
   - Name: `DD_TRACE_MSMQ_ENABLED`, Value: `true`
6. Repeat for **MsmqReceiverPool** (change `DD_SERVICE` to `msmq-receiver`)
7. Restart both application pools

## Step 5: Generate and View Traces

### Generate Traffic

```powershell
# Send test orders
for ($i = 1; $i -le 10; $i++) {
    Invoke-RestMethod -Uri "http://localhost:8081/api/order/test" -Method Get
    Start-Sleep -Seconds 1
}
```

### View Traces in Datadog

1. Log in to [Datadog](https://app.datadoghq.com)
2. Navigate to **APM → Traces**
3. Filter by:
   - Environment: `sandbox` (or `production` for IIS)
   - Service: `msmq-sender` or `msmq-receiver`

### What to Expect in Traces

Your distributed traces should show:

```
HTTP POST /api/order
  └─ msmq.send (Sender App)
      └─ msmq.receive (Receiver App)
          └─ order.process (Receiver App)
```

Each span will include:
- **Service name**: `msmq-sender` or `msmq-receiver`
- **Operation**: HTTP request, MSMQ send/receive
- **Duration**: How long each operation took
- **Tags**: Order ID, customer name, queue name, etc.
- **Errors**: Any exceptions that occurred

## Troubleshooting

### No Traces Appearing

1. **Check Datadog Agent status**:
```powershell
Get-Service datadogagent
# Should be "Running"
```

2. **Enable debug logging**:
```powershell
$env:DD_TRACE_DEBUG = "true"
$env:DD_TRACE_LOG_DIRECTORY = "C:\logs\datadog"

# Create log directory
New-Item -ItemType Directory -Force -Path "C:\logs\datadog"
```

3. **Check tracer logs**:
- Look in `C:\logs\datadog\dotnet-tracer-managed-*.log`
- Look for errors or warnings

4. **Verify profiler is loaded**:
```powershell
# In application logs, you should see:
# "Datadog .NET Tracer loaded"
```

5. **Check Datadog Agent logs**:
```powershell
# View agent logs
Get-Content "C:\ProgramData\Datadog\logs\agent.log" -Tail 50
```

### MSMQ Traces Not Connected

1. **Verify MSMQ instrumentation is enabled**:
```powershell
$env:DD_TRACE_MSMQ_ENABLED
# Should return "true"
```

2. **Check supported integrations**:
- Datadog automatically instruments `System.Messaging`
- Ensure you're using the `System.Messaging` NuGet package

3. **Verify trace context propagation**:
- MSMQ messages should include Datadog trace context headers
- Check that both sender and receiver have the same environment

### Performance Issues

If tracing causes performance degradation:

1. **Adjust sampling rate**:
```powershell
$env:DD_TRACE_SAMPLE_RATE = "0.5"  # Sample 50% of traces
```

2. **Disable specific integrations**:
```powershell
$env:DD_TRACE_ASPNETCORE_ENABLED = "false"  # Disable if not needed
```

## Advanced Configuration

### Custom Tags

Add custom tags to all traces:

```powershell
$env:DD_TAGS = "team:backend,app:msmq-demo,region:us-east-1"
```

### Service Mapping

Map service names for better organization:

```powershell
$env:DD_SERVICE_MAPPING = "msmq:message-queue,sql-server:database"
```

### Trace Analytics

Enable 100% sampling for specific operations:

```powershell
$env:DD_TRACE_ANALYTICS_ENABLED = "true"
$env:DD_MSMQ_ANALYTICS_ENABLED = "true"
```

### Log Injection

Correlate logs with traces:

```powershell
$env:DD_LOGS_INJECTION = "true"
```

Then configure your logging framework to output trace IDs.

## Resources

- [Datadog .NET Tracer Documentation](https://docs.datadoghq.com/tracing/trace_collection/dd_libraries/dotnet-core/)
- [Datadog Agent Documentation](https://docs.datadoghq.com/agent/)
- [MSMQ Integration](https://docs.datadoghq.com/integrations/msmq/)
- [Datadog APM Overview](https://docs.datadoghq.com/tracing/)

## Support

For issues:
1. Check [Datadog .NET Tracer GitHub Issues](https://github.com/DataDog/dd-trace-dotnet/issues)
2. Contact Datadog Support
3. Review logs as described in Troubleshooting section

