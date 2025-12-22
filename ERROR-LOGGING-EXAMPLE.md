# Datadog Error Logging Examples

This document shows examples of how errors are logged with Datadog-standardized fields.

## 📋 Datadog Error Fields

All exceptions automatically include these fields:

| Field | Description | Example |
|-------|-------------|---------|
| `error.message` | The exception message | "The process cannot access the file" |
| `error.type` | The exception type/class | "System.IO.IOException" |
| `error.stack` | The full stack trace | "at System.IO.FileStream..." |
| `error.handling` | Whether error was handled | "handled" or "unhandled" |

---

## 🔍 Example 1: Handled Error (LogError)

**Scenario:** MSMQ queue doesn't exist

**Code:**
```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Error receiving message from queue");
    return null;
}
```

**JSON Log Output:**
```json
{
  "@t": "2025-12-22T14:30:00.0000000Z",
  "@mt": "Error receiving message from queue",
  "@l": "Error",
  "service": "ReceiverWebApp",
  "version": "6bd7f64",
  "dd.service": "ReceiverWebApp",
  "dd.version": "6bd7f64",
  "dd.env": "testing",
  "error.message": "Queue does not exist: .\\private$\\OrderQueue",
  "error.type": "Experimental.System.Messaging.MessageQueueException",
  "error.stack": "   at Experimental.System.Messaging.MessageQueue.MQCacheableInfo.get_ReadHandle()\n   at Experimental.System.Messaging.MessageQueue.Receive(TimeSpan timeout)\n   at ReceiverWebApp.Services.MsmqReceiverService.ReceiveMessage() in C:\\path\\to\\MsmqReceiverService.cs:line 45",
  "error.handling": "handled"
}
```

---

## 🔍 Example 2: Unhandled Error (LogFatal)

**Scenario:** Application startup failure

**Code:**
```csharp
catch (Exception ex)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
```

**JSON Log Output:**
```json
{
  "@t": "2025-12-22T14:30:00.0000000Z",
  "@mt": "Application terminated unexpectedly",
  "@l": "Fatal",
  "service": "SenderWebApp",
  "version": "6bd7f64",
  "dd.service": "SenderWebApp",
  "dd.version": "6bd7f64",
  "dd.env": "testing",
  "error.message": "Unable to start Kestrel.",
  "error.type": "System.InvalidOperationException",
  "error.stack": "   at Microsoft.AspNetCore.Server.Kestrel.Core.KestrelServer.StartAsync[TContext]()\n   at Program.<Main>$(String[] args) in C:\\path\\to\\Program.cs:line 30",
  "error.handling": "unhandled"
}
```

---

## 🔍 Example 3: Order Processing Error

**Scenario:** Failed to process an order

**Code:**
```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Error processing order {OrderId}", order.OrderId);
    order.Status = "Failed";
}
```

**JSON Log Output:**
```json
{
  "@t": "2025-12-22T14:30:00.0000000Z",
  "@mt": "Error processing order {OrderId}",
  "@l": "Error",
  "OrderId": "ORD-1234",
  "service": "ReceiverWebApp",
  "version": "6bd7f64",
  "dd.service": "ReceiverWebApp",
  "dd.version": "6bd7f64",
  "dd.env": "testing",
  "error.message": "Object reference not set to an instance of an object.",
  "error.type": "System.NullReferenceException",
  "error.stack": "   at ReceiverWebApp.Services.MessageProcessorService.ProcessOrder(OrderMessage order) in C:\\path\\to\\MessageProcessorService.cs:line 58",
  "error.handling": "handled"
}
```

---

## 🔍 Example 4: MSMQ Send Failure

**Scenario:** Failed to send message to MSMQ

**Code:**
```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Error sending message. OrderId: {OrderId}", message.OrderId);
    throw;
}
```

**JSON Log Output:**
```json
{
  "@t": "2025-12-22T14:30:00.0000000Z",
  "@mt": "Error sending message. OrderId: {OrderId}",
  "@l": "Error",
  "OrderId": "TEST-5678",
  "service": "SenderWebApp",
  "version": "6bd7f64",
  "dd.service": "SenderWebApp",
  "dd.version": "6bd7f64",
  "dd.env": "testing",
  "error.message": "Access to Message Queuing system is denied.",
  "error.type": "Experimental.System.Messaging.MessageQueueException",
  "error.stack": "   at Experimental.System.Messaging.MessageQueue.Send(Object obj)\n   at SenderWebApp.Services.MsmqService.SendMessage(OrderMessage message) in C:\\path\\to\\MsmqService.cs:line 56",
  "error.handling": "handled"
}
```

---

## 📊 Datadog Integration

### How Datadog Uses These Fields

1. **Error Tracking**: Groups similar errors by `error.type` and `error.message`
2. **Stack Traces**: Shows full context with `error.stack`
3. **Error Rates**: Monitors handled vs unhandled errors
4. **Version Correlation**: Links errors to specific code versions via `dd.version`
5. **Trace Correlation**: Connects errors to distributed traces via trace_id

### Viewing in Datadog

**APM > Error Tracking:**
- Errors grouped by type and message
- Stack traces visible
- Version information included
- Linked to traces

**Logs > Logs Explorer:**
```
service:SenderWebApp @error.handling:unhandled
```

**Trace View:**
- Errors automatically attached to spans
- Full error context in span metadata
- Version tag visible in trace details

---

## 🎯 Error Handling Strategy

### Handled Errors (LogError)
- Caught and logged
- Application continues
- `error.handling: "handled"`
- Use for: recoverable errors, retry scenarios, validation failures

### Unhandled Errors (LogFatal)
- Application terminates
- `error.handling: "unhandled"`
- Use for: startup failures, critical errors, unrecoverable states

---

## ✅ Testing Error Logging

**Trigger an error to test:**

```powershell
# Stop MSMQ service to simulate error
Stop-Service MSMQ

# Send a message (will fail)
curl -X POST http://localhost:8081/api/order/test

# Check logs
Get-EventLog -LogName Application -Source SenderWebApp -Newest 1
```

**Check Datadog:**
1. Go to APM > Error Tracking
2. Filter by `service:SenderWebApp`
3. Find the MessageQueueException
4. Verify all error fields are present

---

## 🚀 Benefits

✅ **Standardized**: All errors follow Datadog conventions
✅ **Traceable**: Linked to versions via git SHA
✅ **Searchable**: Easy to filter and query in Datadog
✅ **Actionable**: Full stack traces for debugging
✅ **Monitored**: Track error rates and patterns

