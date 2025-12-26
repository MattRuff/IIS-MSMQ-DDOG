# Synchronous MSMQ Receive Test

## What Changed

The receiver has been converted from **async event-driven** to **synchronous polling** to test Datadog's auto-instrumentation.

### Before (Async Pattern - NOT Auto-Instrumented)

```csharp
// Event-driven async pattern
_queue.ReceiveCompleted += OnReceiveCompleted;
_queue.BeginReceive();

// Later...
private void OnReceiveCompleted(object sender, ReceiveCompletedEventArgs e)
{
    var message = _queue.EndReceive(e.AsyncResult);
    // Process message...
    _queue.BeginReceive(); // Wait for next
}
```

**Result**: ❌ No traces in Datadog APM

---

### After (Synchronous Pattern - Auto-Instrumented Library)

```csharp
// Synchronous blocking receive with timeout
var message = _queue.Receive(TimeSpan.FromSeconds(1));
```

**Expected Result**: ⚠️ **Testing** - `MessageQueue.Receive()` is auto-instrumented, but may not generate traces from background Timer

---

## Why This Matters

According to [Datadog's .NET Framework documentation](https://docs.datadoghq.com/tracing/trace_collection/compatibility/dotnet-framework/#integrations):

> **MSMQ** - Automatic instrumentation for `System.Messaging.MessageQueue`

However, the documentation doesn't specify:
- ✅ Does it instrument `Send()`? (Yes - confirmed working)
- ❓ Does it instrument synchronous `Receive()`? (Testing now)
- ❓ Does it instrument async `BeginReceive()` / `EndReceive()`? (No - confirmed not working)
- ❓ Does it create traces for operations without HTTP parent context? (Testing now)

---

## How to Test

### 1. Pull Latest Changes

```powershell
git pull
```

### 2. Rebuild

```powershell
dotnet build -c Release
```

### 3. Run with Datadog

```powershell
.\build-and-run.ps1
```

### 4. Send Test Orders

```powershell
# Send 3 test orders
curl http://localhost:8081/api/order/test
Start-Sleep -Seconds 2
curl http://localhost:8081/api/order/test
Start-Sleep -Seconds 2
curl http://localhost:8081/api/order/test
```

### 5. Check Application Logs

**Look for these log entries:**

**SenderWebApp (should have trace IDs):**
```json
{
  "@mt": "Message sent successfully. OrderId: {OrderId}",
  "dd_trace_id": "694eb06200000000d388d5124cdefc12",  ← Present
  "dd_span_id": "13412023370429707327"                ← Present
}
```

**ReceiverWebApp (check if trace IDs appear now):**
```json
{
  "@mt": "Message received from MSMQ. OrderId: {OrderId}",
  "dd_trace_id": "???",  ← Will this appear now?
  "dd_span_id": "???"    ← Will this appear now?
}
```

### 6. Check Datadog APM

**Navigate to**: `https://app.datadoghq.com/apm/traces`

**Look for**:
- ✅ `msmq.send` spans from SenderWebApp (should exist)
- ⚠️ `msmq.receive` spans from ReceiverWebApp (testing if these appear)

---

## Expected Outcomes

### Scenario A: Synchronous Receive() IS Traced (Best Case)

**If you see:**
- ✅ `dd_trace_id` and `dd_span_id` in ReceiverWebApp logs
- ✅ `msmq.receive` spans in Datadog APM
- ✅ Spans show operation name like `msmq.receive` or `System.Messaging.MessageQueue.Receive`

**Then**: Synchronous `Receive()` generates traces even from background workers!

---

### Scenario B: Synchronous Receive() NOT Traced (Expected)

**If you see:**
- ❌ No `dd_trace_id` or `dd_span_id` in ReceiverWebApp logs
- ❌ No `msmq.receive` spans in Datadog APM
- ✅ Messages still processed (logs show "Order processed successfully")

**Then**: Auto-instrumentation requires HTTP parent context. Background workers don't generate traces.

---

### Scenario C: Partial Tracing (Interesting Case)

**If you see:**
- ⚠️ `msmq.receive` spans appear in Datadog, but orphaned (no connection to `msmq.send`)
- ⚠️ Traces are fragmented (send and receive as separate root spans)

**Then**: Auto-instrumentation works but doesn't propagate context through MSMQ message properties.

---

## Key Differences from Previous Implementation

| Aspect | Async (Before) | Synchronous (Now) |
|--------|----------------|-------------------|
| **Method** | `BeginReceive()` / `EndReceive()` | `Receive(timeout)` |
| **Pattern** | Event-driven callback | Blocking poll with timeout |
| **In-Memory Queue** | Yes (event fills queue, Timer drains) | No (direct receive-and-process) |
| **Auto-Instrumented?** | ❌ No (confirmed) | ⚠️ Testing now |
| **Complexity** | Higher (event handlers, locks, queue) | Lower (simple polling loop) |

---

## No Manual Instrumentation

This implementation uses **ZERO manual instrumentation**:
- ❌ No `Datadog.Trace` package
- ❌ No `Tracer.Instance` calls
- ❌ No `StartActive()` or `SetTag()` calls
- ✅ Pure `System.Messaging.MessageQueue` API
- ✅ Relying 100% on Datadog's automatic instrumentation

---

## What to Report

After testing, report:

1. **Do receiver logs show `dd_trace_id` and `dd_span_id`?** (Yes/No)
2. **Does Datadog APM show `msmq.receive` spans?** (Yes/No)
3. **Are send and receive spans connected?** (Yes/No/N/A)
4. **Any errors in Datadog debug logs?** (Attach snippet if relevant)

---

## Rollback if Needed

If synchronous receive doesn't work better than async:

```powershell
git revert HEAD
git push
```

This will restore the event-driven pattern.

