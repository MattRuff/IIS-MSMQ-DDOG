# Check Service Startup Errors
# Run this to see why the service won't start

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Service Startup Error Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check System Event Log for service errors
Write-Host "1. Checking System Event Log..." -ForegroundColor Yellow
$events = Get-EventLog -LogName System -Source "Service Control Manager" -Newest 10 -ErrorAction SilentlyContinue | 
    Where-Object { $_.Message -like "*MsmqSenderService*" -or $_.Message -like "*MsmqReceiverService*" }

if ($events) {
    foreach ($event in $events) {
        Write-Host "`nTime: $($event.TimeGenerated)" -ForegroundColor Gray
        Write-Host "Type: $($event.EntryType)" -ForegroundColor $(if ($event.EntryType -eq "Error") { "Red" } else { "Yellow" })
        Write-Host "Message:" -ForegroundColor White
        Write-Host $event.Message -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host "  No service control manager events found" -ForegroundColor Yellow
}

# Check Application Event Log
Write-Host "`n2. Checking Application Event Log..." -ForegroundColor Yellow
$appEvents = Get-EventLog -LogName Application -Newest 10 -ErrorAction SilentlyContinue | 
    Where-Object { $_.Source -like "*Sender*" -or $_.Source -like "*Receiver*" }

if ($appEvents) {
    foreach ($event in $appEvents) {
        Write-Host "`nTime: $($event.TimeGenerated)" -ForegroundColor Gray
        Write-Host "Source: $($event.Source)" -ForegroundColor White
        Write-Host "Type: $($event.EntryType)" -ForegroundColor $(if ($event.EntryType -eq "Error") { "Red" } else { "Yellow" })
        Write-Host "Message:" -ForegroundColor White
        Write-Host $event.Message -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host "  No application events found" -ForegroundColor Yellow
}

# Try to run the sender manually to see the error
Write-Host "`n3. Testing Manual Execution..." -ForegroundColor Yellow
$exePath = "C:\Users\matthew.ruyffelaert\Documents\IIS-MSMQ-Lab\IIS-MSMQ-DDOG\SenderWebApp\bin\Release\net48\SenderWebApp.exe"

if (Test-Path $exePath) {
    Write-Host "  Executable found: $exePath" -ForegroundColor Green
    Write-Host "  Attempting to run for 3 seconds..." -ForegroundColor Gray
    
    try {
        $process = Start-Process -FilePath $exePath -PassThru -NoNewWindow
        Start-Sleep -Seconds 3
        
        if (!$process.HasExited) {
            Write-Host "  [SUCCESS] Application started successfully!" -ForegroundColor Green
            Write-Host "  The app can run - this is a Windows Service configuration issue" -ForegroundColor Yellow
            Stop-Process -Id $process.Id -Force
        } else {
            Write-Host "  [ERROR] Application exited immediately with code: $($process.ExitCode)" -ForegroundColor Red
        }
    } catch {
        Write-Host "  [ERROR] Failed to start: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "  [ERROR] Executable not found!" -ForegroundColor Red
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Possible Issues:" -ForegroundColor Yellow
Write-Host "  1. ASP.NET Core 2.2 on .NET Framework requires special service hosting" -ForegroundColor White
Write-Host "  2. Missing dependencies or configuration" -ForegroundColor White
Write-Host "  3. The app may not be service-aware" -ForegroundColor White
Write-Host ""
Write-Host "Recommendation:" -ForegroundColor Yellow
Write-Host "  Run as console app first to ensure it works:" -ForegroundColor White
Write-Host "  cd SenderWebApp\bin\Release\net48" -ForegroundColor Cyan
Write-Host "  .\SenderWebApp.exe" -ForegroundColor Cyan
Write-Host ""

