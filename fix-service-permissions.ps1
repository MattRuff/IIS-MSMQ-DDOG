# Fix all permissions for NetworkService to run the receiver

$ErrorActionPreference = "Stop"

Write-Host "`n=== FIX RECEIVER SERVICE PERMISSIONS ===" -ForegroundColor Cyan

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    exit 1
}

$receiverDir = "C:\Users\matthew.ruyffelaert\Documents\IIS-MSMQ-Lab\IIS-MSMQ-DDOG\ReceiverWebApp"
$receiverBinDir = "$receiverDir\bin\Release\net48"
$logDir = "$receiverBinDir\logs"

Write-Host "`nGranting NetworkService permissions..." -ForegroundColor Yellow

# 1. Grant read/execute to entire receiver directory
Write-Host "`n1. Granting Read/Execute to receiver directory..." -ForegroundColor Gray
try {
    $acl = Get-Acl $receiverDir
    $permission = "NETWORK SERVICE","ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    Set-Acl $receiverDir $acl
    Write-Host "   [OK] $receiverDir" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Grant read/execute to bin directory (be explicit)
Write-Host "`n2. Granting Read/Execute to bin directory..." -ForegroundColor Gray
try {
    $acl = Get-Acl $receiverBinDir
    $permission = "NETWORK SERVICE","ReadAndExecute","ContainerInherit,ObjectInherit","None","Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    Set-Acl $receiverBinDir $acl
    Write-Host "   [OK] $receiverBinDir" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Create log directory if it doesn't exist
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Write-Host "`n   Created log directory: $logDir" -ForegroundColor Gray
}

# 4. Grant full control to log directory
Write-Host "`n3. Granting Full Control to log directory..." -ForegroundColor Gray
try {
    $acl = Get-Acl $logDir
    $permission = "NETWORK SERVICE","FullControl","ContainerInherit,ObjectInherit","None","Allow"
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($accessRule)
    Set-Acl $logDir $acl
    Write-Host "   [OK] $logDir" -ForegroundColor Green
} catch {
    Write-Host "   [ERROR] $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Grant read access to appsettings.json specifically
Write-Host "`n4. Granting Read to appsettings.json..." -ForegroundColor Gray
$appsettings = "$receiverBinDir\appsettings.json"
if (Test-Path $appsettings) {
    try {
        $acl = Get-Acl $appsettings
        $permission = "NETWORK SERVICE","Read","None","None","Allow"
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.SetAccessRule($accessRule)
        Set-Acl $appsettings $acl
        Write-Host "   [OK] $appsettings" -ForegroundColor Green
    } catch {
        Write-Host "   [ERROR] $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "   [WARN] appsettings.json not found" -ForegroundColor Yellow
}

# 6. Verify current service configuration
Write-Host "`n5. Verifying service configuration..." -ForegroundColor Gray
$service = Get-WmiObject -Class Win32_Service -Filter "Name='MsmqReceiverService'"
if ($service) {
    Write-Host "   Service Account: $($service.StartName)" -ForegroundColor $(if ($service.StartName -like "*NetworkService*") { "Green" } else { "Red" })
    Write-Host "   Service Path: $($service.PathName)" -ForegroundColor Gray
} else {
    Write-Host "   [ERROR] Service not found!" -ForegroundColor Red
}

Write-Host "`n[SUCCESS] Permissions configured!" -ForegroundColor Green
Write-Host "`nNow try starting the service:" -ForegroundColor Yellow
Write-Host "  Start-Service -Name MsmqReceiverService" -ForegroundColor White
Write-Host ""

