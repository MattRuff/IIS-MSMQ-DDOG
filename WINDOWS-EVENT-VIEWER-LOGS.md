# Windows Event Viewer Logs

Both `SenderWebApp` and `ReceiverWebApp` write **all logs** to the Windows Event Viewer's **Application** log.

## Log Configuration

### Log Destinations

All logs are written to **three locations** simultaneously:

| Destination | Format | Level | Purpose |
|-------------|--------|-------|---------|
| **Console** | JSON | Verbose+ | Real-time monitoring during development |
| **File** | JSON | Verbose+ | Persistent logs for analysis |
| **Windows Event Viewer** | Text | Verbose+ | System-wide logging, Windows Services integration |

### Event Log Details

- **Log Name**: `Application`
- **Event Sources**: 
  - `SenderWebApp` (for sender logs)
  - `ReceiverWebApp` (for receiver logs)
- **Minimum Level**: `Verbose` (captures ALL log levels)
- **Auto-Registration**: Sources are automatically created if they don't exist (`manageEventSource: true`)

---

## How to View Logs in Event Viewer

### Step 1: Open Event Viewer

**Option A: Via Run Dialog**
```
Win + R  →  Type: eventvwr.msc  →  Press Enter
```

**Option B: Via Start Menu**
```
Start Menu  →  Search "Event Viewer"  →  Click "Event Viewer"
```

**Option C: Via PowerShell**
```powershell
eventvwr
```

---

### Step 2: Navigate to Application Logs

In Event Viewer:
1. Expand **Windows Logs** in the left pane
2. Click **Application**

---

### Step 3: Filter by Source

To see only logs from your applications:

**Filter by SenderWebApp:**
1. Right-click **Application**
2. Select **Filter Current Log...**
3. In the **Event sources** dropdown, check **SenderWebApp**
4. Click **OK**

**Filter by ReceiverWebApp:**
1. Right-click **Application**
2. Select **Filter Current Log...**
3. In the **Event sources** dropdown, check **ReceiverWebApp**
4. Click **OK**

**Filter by Both:**
- Check both **SenderWebApp** and **ReceiverWebApp** in the filter

---

### Step 4: View Log Details

Click any log entry to see:
- **General Tab**: Timestamp, level, source, event ID
- **Details Tab**: Full log message with all properties (JSON structure)

---

## PowerShell: Query Event Logs

### Get Last 50 Sender Logs
```powershell
Get-EventLog -LogName Application -Source "SenderWebApp" -Newest 50 | Format-Table TimeGenerated, EntryType, Message -AutoSize
```

### Get Last 50 Receiver Logs
```powershell
Get-EventLog -LogName Application -Source "ReceiverWebApp" -Newest 50 | Format-Table TimeGenerated, EntryType, Message -AutoSize
```

### Get All Logs from Both Apps (Last Hour)
```powershell
$since = (Get-Date).AddHours(-1)
Get-EventLog -LogName Application | Where-Object {
    ($_.Source -eq "SenderWebApp" -or $_.Source -eq "ReceiverWebApp") -and $_.TimeGenerated -gt $since
} | Format-Table TimeGenerated, Source, EntryType, Message -AutoSize
```

### Get Error Logs Only
```powershell
Get-EventLog -LogName Application -Source "SenderWebApp","ReceiverWebApp" -EntryType Error -Newest 20
```

### Export Logs to File
```powershell
Get-EventLog -LogName Application -Source "SenderWebApp","ReceiverWebApp" -Newest 100 | 
    Export-Csv -Path "C:\Temp\app-logs.csv" -NoTypeInformation
```

---

## Log Levels in Event Viewer

Serilog levels map to Windows Event Log entry types:

| Serilog Level | Event Viewer Type | When to Use |
|---------------|-------------------|-------------|
| **Verbose** | Information | Detailed trace information |
| **Debug** | Information | Debugging information |
| **Information** | Information | General informational messages |
| **Warning** | Warning | Potential issues, non-critical |
| **Error** | Error | Errors and exceptions |
| **Fatal** | Error | Critical failures |

---

## Event Log Properties

Each log entry includes:

### Standard Properties
- `@t`: Timestamp (ISO 8601)
- `@mt`: Message template
- `@l`: Log level (Verbose, Debug, Information, Warning, Error, Fatal)

### Datadog Properties
- `dd_service`: Service name (SenderWebApp or ReceiverWebApp)
- `dd_version`: Git commit hash
- `dd_env`: Environment (from `DD_ENV` variable or "development")
- `dd_trace_id`: Distributed trace ID (if in traced context)
- `dd_span_id`: Span ID (if in traced context)

### Application Properties
- `service`: Application service name
- `version`: Git commit hash
- Custom properties per log message (OrderId, CustomerName, etc.)

---

## Troubleshooting

### Issue: No Logs Appear in Event Viewer

**Check 1: Are applications running?**
```powershell
Get-Process -Name "SenderWebApp","ReceiverWebApp" -ErrorAction SilentlyContinue
```

**Check 2: Are event sources registered?**
```powershell
Get-EventLog -List | Where-Object { $_.Log -eq "Application" } | 
    Select-Object -ExpandProperty Entries | 
    Where-Object { $_.Source -match "SenderWebApp|ReceiverWebApp" } | 
    Select-Object -First 10
```

**Check 3: Run as Administrator (for source registration)**
- First run may require Administrator privileges to create event sources
- Subsequent runs work with normal user privileges

**Check 4: Check Serilog configuration**
- Verify `Serilog.Sinks.EventLog` package is installed
- Check Program.cs for EventLog configuration

---

### Issue: "Cannot create event source" Error

This happens if:
1. Application doesn't have permission to create event source
2. Event source already exists with different configuration

**Solution 1: Run as Administrator (First Time)**
```powershell
# Right-click PowerShell → "Run as Administrator"
.\build-and-run.ps1
```

**Solution 2: Pre-register Event Sources (Manual)**
```powershell
# Run as Administrator
New-EventLog -LogName Application -Source "SenderWebApp"
New-EventLog -LogName Application -Source "ReceiverWebApp"
```

**Solution 3: Remove and Re-create**
```powershell
# Run as Administrator
Remove-EventLog -Source "SenderWebApp"
Remove-EventLog -Source "ReceiverWebApp"

# Then restart applications
.\build-and-run.ps1
```

---

## Best Practices

### For Development
- Use **Console** output for real-time feedback
- Use **File** logs for detailed analysis
- Use **Event Viewer** for system-wide context

### For Windows Services
- Primary log source should be **Event Viewer** (console not visible)
- Filter by source to isolate service-specific logs
- Use PowerShell scripts to automate log collection

### For Production
- Configure log retention policies
- Export logs regularly for archival
- Monitor Event Viewer for Error/Fatal entries

---

## Automatic Log Rotation

- **File Logs**: Automatically rotate daily, keep last 7 days
- **Event Viewer**: Uses Windows default retention (overwrite when full or manual clear)
- **Console Logs**: Not persisted (real-time only)

---

## See Also

- [Serilog Event Log Sink Documentation](https://github.com/serilog/serilog-sinks-eventlog)
- [Windows Event Viewer Guide](https://docs.microsoft.com/en-us/windows/win32/eventlog/event-logging)
- `README.md` - Main project documentation
- `WINDOWS-SERVICES.md` - Running as Windows Services

