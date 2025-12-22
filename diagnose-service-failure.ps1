# Diagnose why the receiver service won't start

Write-Host "`n=== RECEIVER SERVICE FAILURE DIAGNOSIS ===" -ForegroundColor Cyan

# 1. Check System Event Log for Service Control Manager errors
Write-Host "`n1. System Event Log - Service Failures:" -ForegroundColor Yellow
$systemErrors = Get-EventLog -LogName System -Source "Service Control Manager" -Newest 10 -ErrorAction SilentlyContinue | 
    Where-Object { $_.Message -like "*MsmqReceiverService*" -or $_.Message -like "*Receiver*" }

if ($systemErrors) {
    $systemErrors | ForEach-Object {
        Write-Host "`n[$($_.TimeGenerated)] Event ID: $($_.EventID)" -ForegroundColor Red
        Write-Host $_.Message -ForegroundColor Gray
    }
} else {
    Write-Host "No System log errors found for receiver service" -ForegroundColor Green
}

# 2. Check Application Event Log for receiver startup errors
Write-Host "`n2. Application Event Log - Receiver Errors:" -ForegroundColor Yellow
$appErrors = Get-EventLog -LogName Application -Source ReceiverWebApp -EntryType Error -Newest 5 -ErrorAction SilentlyContinue

if ($appErrors) {
    $appErrors | ForEach-Object {
        Write-Host "`n[$($_.TimeGenerated)]" -ForegroundColor Red
        Write-Host $_.Message -ForegroundColor Gray
    }
} else {
    Write-Host "No application errors found" -ForegroundColor Green
}

# 3. Check receiver service configuration
Write-Host "`n3. Service Configuration:" -ForegroundColor Yellow
$service = Get-WmiObject -Class Win32_Service -Filter "Name='MsmqReceiverService'" -ErrorAction SilentlyContinue
if ($service) {
    Write-Host "  Name: $($service.Name)"
    Write-Host "  Display Name: $($service.DisplayName)"
    Write-Host "  State: $($service.State)"
    Write-Host "  Start Mode: $($service.StartMode)"
    Write-Host "  Start Name (Account): $($service.StartName)"
    Write-Host "  Path: $($service.PathName)"
} else {
    Write-Host "  Service not found!" -ForegroundColor Red
}

# 4. Check if executable exists and is accessible
Write-Host "`n4. Executable Check:" -ForegroundColor Yellow
$exePath = "C:\Users\matthew.ruyffelaert\Documents\IIS-MSMQ-Lab\IIS-MSMQ-DDOG\ReceiverWebApp\bin\Release\net8.0\ReceiverWebApp.exe"
if (Test-Path $exePath) {
    Write-Host "  Executable exists: YES" -ForegroundColor Green
    $fileInfo = Get-Item $exePath
    Write-Host "  Size: $($fileInfo.Length) bytes"
    Write-Host "  Modified: $($fileInfo.LastWriteTime)"
} else {
    Write-Host "  Executable NOT FOUND!" -ForegroundColor Red
}

# 5. Check MSMQ queue exists
Write-Host "`n5. MSMQ Queue Check:" -ForegroundColor Yellow
try {
    Add-Type -AssemblyName "System.Messaging"
    $queuePath = ".\private$\OrderQueue"
    if ([System.Messaging.MessageQueue]::Exists($queuePath)) {
        Write-Host "  Queue exists: YES" -ForegroundColor Green
        $queue = New-Object System.Messaging.MessageQueue($queuePath)
        Write-Host "  Path: $($queue.Path)"
        Write-Host "  Format Name: $($queue.FormatName)"
        
        # Try to get permissions
        try {
            Write-Host "`n  Queue Permissions:" -ForegroundColor Cyan
            $queue.GetAccessControl() | Out-String | Write-Host -ForegroundColor Gray
        } catch {
            Write-Host "  Could not read permissions: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Queue does NOT exist!" -ForegroundColor Red
    }
} catch {
    Write-Host "  Error checking queue: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. Try to run the receiver manually to see the error
Write-Host "`n6. Manual Execution Test:" -ForegroundColor Yellow
Write-Host "  Attempting to run receiver executable directly..." -ForegroundColor Gray
Write-Host "  (This will show the actual error if there's a startup problem)" -ForegroundColor Gray
Write-Host ""

try {
    $process = Start-Process -FilePath $exePath -PassThru -Wait -WindowStyle Hidden
    Write-Host "  Process exited with code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Red" })
} catch {
    Write-Host "  Failed to execute: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== SUGGESTED ACTIONS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Based on the errors above, try:" -ForegroundColor Yellow
Write-Host "  1. Check System Event Log for the actual Windows error"
Write-Host "  2. Verify NetworkService has permissions to the queue"
Write-Host "  3. Check Application Event Log for startup exceptions"
Write-Host "  4. Try running the .exe manually to see immediate errors"
Write-Host ""

