# Grant NetworkService full permissions to MSMQ queue
# Run this as Administrator

$ErrorActionPreference = "Stop"

Write-Host "`n=== GRANT MSMQ QUEUE PERMISSIONS ===" -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

$queuePath = ".\private$\OrderQueue"

Write-Host "`nQueue Path: $queuePath" -ForegroundColor Yellow

# Load MSMQ assembly
Write-Host "`nLoading System.Messaging assembly..." -ForegroundColor Gray
try {
    Add-Type -AssemblyName "System.Messaging"
    Write-Host "  [OK] Assembly loaded" -ForegroundColor Green
} catch {
    Write-Host "  [ERROR] Failed to load System.Messaging: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check if queue exists
Write-Host "`nChecking if queue exists..." -ForegroundColor Gray
if (-not [System.Messaging.MessageQueue]::Exists($queuePath)) {
    Write-Host "  [ERROR] Queue does not exist: $queuePath" -ForegroundColor Red
    Write-Host "  Create the queue first by starting the Sender service or running:" -ForegroundColor Yellow
    Write-Host "  [System.Messaging.MessageQueue]::Create('$queuePath')" -ForegroundColor Yellow
    exit 1
}
Write-Host "  [OK] Queue exists" -ForegroundColor Green

# Open the queue
Write-Host "`nOpening queue..." -ForegroundColor Gray
try {
    $queue = New-Object System.Messaging.MessageQueue($queuePath)
    Write-Host "  [OK] Queue opened" -ForegroundColor Green
    Write-Host "  Format Name: $($queue.FormatName)" -ForegroundColor Gray
} catch {
    Write-Host "  [ERROR] Failed to open queue: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Show current permissions
Write-Host "`nCurrent Queue Permissions:" -ForegroundColor Yellow
try {
    $currentPerms = $queue.GetAccessControl()
    $currentPerms.GetAccessRules($true, $true, [System.Security.Principal.NTAccount]) | 
        ForEach-Object {
            Write-Host "  $($_.IdentityReference): $($_.AccessControlType) - $($_.AccessMaskDisplay)" -ForegroundColor Gray
        }
} catch {
    Write-Host "  [WARN] Could not read current permissions: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Grant NetworkService full control
Write-Host "`nGranting NETWORK SERVICE full control..." -ForegroundColor Yellow
try {
    # Try multiple account name formats
    $accountNames = @("NETWORK SERVICE", "NT AUTHORITY\NETWORK SERVICE", "NT AUTHORITY\NetworkService")
    $success = $false
    
    foreach ($accountName in $accountNames) {
        try {
            Write-Host "  Trying account name: $accountName" -ForegroundColor Gray
            $queue.SetPermissions(
                $accountName, 
                [System.Messaging.MessageQueueAccessRights]::FullControl,
                [System.Messaging.AccessControlEntryType]::Allow
            )
            Write-Host "  [OK] Permissions granted using: $accountName" -ForegroundColor Green
            $success = $true
            break
        } catch {
            Write-Host "  Failed with $accountName : $($_.Exception.Message)" -ForegroundColor Gray
        }
    }
    
    if (-not $success) {
        throw "All account name formats failed"
    }
} catch {
    Write-Host "  [ERROR] Failed to grant permissions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verify permissions were granted
Write-Host "`nVerifying new permissions..." -ForegroundColor Yellow
try {
    $newPerms = $queue.GetAccessControl()
    $networkServicePerm = $newPerms.GetAccessRules($true, $true, [System.Security.Principal.NTAccount]) | 
        Where-Object { $_.IdentityReference -like "*NETWORK SERVICE*" }
    
    if ($networkServicePerm) {
        Write-Host "  [OK] NETWORK SERVICE permissions verified:" -ForegroundColor Green
        $networkServicePerm | ForEach-Object {
            Write-Host "    $($_.IdentityReference): $($_.AccessControlType) - $($_.AccessMaskDisplay)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  [WARN] Could not verify NETWORK SERVICE permissions" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  [WARN] Could not verify permissions: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Close queue
$queue.Dispose()

Write-Host "`n[SUCCESS] Queue permissions configured!" -ForegroundColor Green
Write-Host "`nYou can now try starting the receiver service:" -ForegroundColor Yellow
Write-Host "  Start-Service -Name MsmqReceiverService" -ForegroundColor White
Write-Host ""

