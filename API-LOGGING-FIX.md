# API Call Logging Fix

## Problem

Logs triggered during API calls (e.g., `Log.Information()` in controllers) were **not being captured** in Console, File, or Event Viewer outputs.

---

## Root Cause

Web API 2 / OWIN applications need **explicit middleware** to enrich Serilog logs with HTTP request context. Without this:
- Logs from controller actions had no HTTP context
- No request/response logging
- No timing information
- No request correlation

---

## Solution

Added **Serilog Web API enrichment** and a **custom action filter** to capture HTTP context.

### 1. Added NuGet Packages

Both `SenderWebApp` and `ReceiverWebApp` now include:
```xml
<PackageReference Include="SerilogWeb.Classic" Version="5.1.63" />
<PackageReference Include="SerilogWeb.Classic.WebApi" Version="5.1.63" />
```

### 2. Created Custom Action Filter

`SerilogWebApiFilter.cs` in both projects:
- Captures HTTP method, path, controller, action
- Pushes request properties into `LogContext`
- Logs HTTP request start
- Logs HTTP request completion with status code and timing
- Logs HTTP errors with exceptions

### 3. Registered Filter Globally

In both `OwinStartup.cs` files:
```csharp
config.Filters.Add(new SerilogWebApiFilter());
```

---

## What's Now Logged

### HTTP Request Start
```json
{
  "@t": "2025-12-26T16:00:00.000Z",
  "@mt": "HTTP {HttpMethod} {HttpPath} started",
  "HttpMethod": "GET",
  "HttpPath": "/api/order/test",
  "Controller": "Order",
  "Action": "SendTestOrder",
  "RequestId": "abc-123-def-456",
  "dd_service": "SenderWebApp",
  "dd_trace_id": "12345...",
  "dd_span_id": "67890..."
}
```

### HTTP Request Completion (Success)
```json
{
  "@t": "2025-12-26T16:00:00.250Z",
  "@mt": "HTTP {HttpMethod} {HttpPath} completed with {StatusCode} in {ElapsedMs}ms",
  "HttpMethod": "GET",
  "HttpPath": "/api/order/test",
  "StatusCode": 200,
  "ElapsedMs": 250,
  "Controller": "Order",
  "Action": "SendTestOrder",
  "RequestId": "abc-123-def-456"
}
```

### HTTP Request Completion (Error)
```json
{
  "@t": "2025-12-26T16:00:00.100Z",
  "@mt": "HTTP {HttpMethod} {HttpPath} failed with {StatusCode} in {ElapsedMs}ms",
  "@x": "System.Exception: Something went wrong...",
  "HttpMethod": "POST",
  "HttpPath": "/api/order",
  "StatusCode": 500,
  "ElapsedMs": 100,
  "Controller": "Order",
  "Action": "CreateOrder",
  "error.message": "Something went wrong",
  "error.type": "System.Exception",
  "error.stack": "at ..."
}
```

### Controller Action Logs (Enriched)

All `Log.Information()`, `Log.Error()`, etc. calls inside controller actions now include:
- `HttpMethod`
- `HttpPath`
- `Controller`
- `Action`
- `RequestId`

**Example from OrderController.cs:**
```json
{
  "@t": "2025-12-26T16:00:00.100Z",
  "@mt": "Received order request: {OrderId}",
  "OrderId": "abc-123",
  "HttpMethod": "POST",
  "HttpPath": "/api/order",
  "Controller": "Order",
  "Action": "CreateOrder",
  "RequestId": "xyz-789"
}
```

---

## How to Test

### 1. Pull Latest Changes
```powershell
git pull
```

### 2. Rebuild
```powershell
dotnet restore
dotnet build -c Release
```

### 3. Run Applications
```powershell
.\build-and-run.ps1
```

### 4. Make API Calls

**Test Order:**
```powershell
curl http://localhost:8081/api/order/test
```

**Check Sender Health:**
```powershell
curl http://localhost:8081/api/order/health
```

**Check Receiver Health:**
```powershell
curl http://localhost:8082/api/status/health
```

### 5. Verify Logs

**Console Output:**
- Watch the terminal windows for both applications
- You should see HTTP request start/completion logs
- Controller logs should include HTTP context

**File Output:**
```powershell
# Sender logs
Get-Content "SenderWebApp\bin\Release\net48\logs\sender-*.json" -Tail 50

# Receiver logs
Get-Content "ReceiverWebApp\bin\Release\net48\logs\receiver-*.json" -Tail 50
```

**Event Viewer:**
```powershell
# Open Event Viewer
eventvwr

# Navigate to: Windows Logs → Application
# Filter by: SenderWebApp, ReceiverWebApp

# Or via PowerShell:
Get-EventLog -LogName Application -Source "SenderWebApp","ReceiverWebApp" -Newest 20
```

---

## Log Properties Reference

| Property | Description | Example |
|----------|-------------|---------|
| `HttpMethod` | HTTP verb | `GET`, `POST` |
| `HttpPath` | Request path | `/api/order/test` |
| `Controller` | Controller name | `Order`, `Status` |
| `Action` | Action method name | `SendTestOrder`, `Health` |
| `RequestId` | Unique per request | `abc-123-def-456` |
| `StatusCode` | HTTP status code | `200`, `404`, `500` |
| `ElapsedMs` | Request duration | `250` |
| `dd_trace_id` | Datadog trace ID | (if traced) |
| `dd_span_id` | Datadog span ID | (if traced) |

---

## Benefits

### ✅ Full Request Tracing
Every API call is now logged with:
- Start timestamp
- Completion timestamp
- Duration
- Status code

### ✅ Request Correlation
All logs during a request share the same `RequestId`, making it easy to:
- Group logs by request
- Trace a single request through the system
- Debug specific API calls

### ✅ Error Context
Errors now include:
- HTTP context (method, path, controller, action)
- Request timing
- Full exception details
- Datadog error fields (`error.message`, `error.type`, `error.stack`)

### ✅ Production Debugging
In production, you can:
- Filter Event Viewer by source
- Find slow API calls (high `ElapsedMs`)
- Identify failing endpoints (500 status codes)
- Correlate with Datadog APM traces via `dd_trace_id`

---

## Troubleshooting

### Issue: Still No Logs During API Calls

**Check 1: Is filter registered?**
```csharp
// In OwinStartup.cs, look for:
config.Filters.Add(new SerilogWebApiFilter());
```

**Check 2: Rebuild required**
```powershell
dotnet clean
dotnet build -c Release
```

**Check 3: Restart applications**
- Stop both applications (Ctrl+C)
- Run `.\build-and-run.ps1` again

---

### Issue: Duplicate Logs

If you see duplicate HTTP logs (start/completion logged twice):
- This is expected if you have multiple filters or middleware
- The custom filter ensures logs include HTTP context

---

### Issue: No HTTP Context in Controller Logs

If controller `Log.Information()` calls don't include HTTP properties:
- Ensure `LogContext.PushProperty()` is working in filter
- Check that filter's `OnActionExecuting()` runs before controller action
- Verify filter is registered globally, not per-controller

---

## See Also

- `WINDOWS-EVENT-VIEWER-LOGS.md` - How to view logs in Event Viewer
- `README.md` - Main project documentation
- `SYNCHRONOUS-RECEIVE-TEST.md` - Testing MSMQ auto-instrumentation
- [SerilogWeb.Classic Documentation](https://github.com/serilog-web/classic)

