# Install IIS MSMQ Demo as Windows Services
# Run this script as Administrator

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "IIS MSMQ Demo - Windows Service Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "[ERROR] This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$senderPath = Join-Path $scriptPath "SenderWebApp\bin\Release\net48\SenderWebApp.exe"
$receiverPath = Join-Path $scriptPath "ReceiverWebApp\bin\Release\net48\ReceiverWebApp.exe"

# Service names
$senderServiceName = "MsmqSenderService"
$receiverServiceName = "MsmqReceiverService"

if ($Uninstall) {
    Write-Host "Uninstalling services..." -ForegroundColor Yellow
    Write-Host ""
    
    # Stop and remove Sender service
    Write-Host "Stopping and removing Sender Service..." -ForegroundColor Yellow
    $service = Get-Service -Name $senderServiceName -ErrorAction SilentlyContinue
    if ($service) {
        # Always try to stop, regardless of current status
        Write-Host "  Current status: $($service.Status)" -ForegroundColor Gray
        if ($service.Status -ne "Stopped") {
            try {
                Stop-Service -Name $senderServiceName -Force -ErrorAction Stop
                Write-Host "  [OK] Stop command sent" -ForegroundColor Green
            } catch {
                Write-Host "  [WARN] Stop failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Wait for service to fully stop
            Write-Host "  Waiting for service to stop..." -ForegroundColor Gray
            Start-Sleep -Seconds 5
            
            # Check final status
            $service.Refresh()
            if ($service.Status -eq "Stopped") {
                Write-Host "  [OK] Service stopped" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Service status: $($service.Status)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [OK] Already stopped" -ForegroundColor Green
        }
        
        # Delete the service
        sc.exe delete $senderServiceName
        Write-Host "  [OK] Service removed" -ForegroundColor Green
    } else {
        Write-Host "  Sender service not found (already removed?)" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Stop and remove Receiver service
    Write-Host "Stopping and removing Receiver Service..." -ForegroundColor Yellow
    $service = Get-Service -Name $receiverServiceName -ErrorAction SilentlyContinue
    if ($service) {
        # Always try to stop, regardless of current status
        Write-Host "  Current status: $($service.Status)" -ForegroundColor Gray
        if ($service.Status -ne "Stopped") {
            try {
                Stop-Service -Name $receiverServiceName -Force -ErrorAction Stop
                Write-Host "  [OK] Stop command sent" -ForegroundColor Green
            } catch {
                Write-Host "  [WARN] Stop failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Wait for service to fully stop
            Write-Host "  Waiting for service to stop..." -ForegroundColor Gray
            Start-Sleep -Seconds 5
            
            # Check final status
            $service.Refresh()
            if ($service.Status -eq "Stopped") {
                Write-Host "  [OK] Service stopped" -ForegroundColor Green
            } else {
                Write-Host "  [WARN] Service status: $($service.Status)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  [OK] Already stopped" -ForegroundColor Green
        }
        
        # Delete the service
        sc.exe delete $receiverServiceName
        Write-Host "  [OK] Service removed" -ForegroundColor Green
    } else {
        Write-Host "  Receiver service not found (already removed?)" -ForegroundColor Gray
    }
    
    Write-Host ""
    
    # Kill any processes still using the ports
    Write-Host "Checking for processes using ports..." -ForegroundColor Yellow
    
    # Check port 8081
    $port8081 = netstat -ano | Select-String "8081" | Select-String "LISTENING"
    if ($port8081) {
        $processId = ($port8081 -split '\s+')[-1]
        Write-Host "  Killing process $processId on port 8081..." -ForegroundColor Yellow
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Port 8081 freed" -ForegroundColor Green
    }
    
    # Check port 8082
    $port8082 = netstat -ano | Select-String "8082" | Select-String "LISTENING"
    if ($port8082) {
        $processId = ($port8082 -split '\s+')[-1]
        Write-Host "  Killing process $processId on port 8082..." -ForegroundColor Yellow
        Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Port 8082 freed" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "[SUCCESS] Services Uninstalled" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
}

# Install mode
Write-Host "Building applications..." -ForegroundColor Yellow
dotnet build -c Release --no-restore

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Build successful" -ForegroundColor Green
Write-Host ""

# Check if executables exist
if (-not (Test-Path $senderPath)) {
    Write-Host "[ERROR] Sender executable not found at: $senderPath" -ForegroundColor Red
    Write-Host "Run 'dotnet build -c Release' first" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $receiverPath)) {
    Write-Host "[ERROR] Receiver executable not found at: $receiverPath" -ForegroundColor Red
    Write-Host "Run 'dotnet build -c Release' first" -ForegroundColor Yellow
    exit 1
}

Write-Host "Installing services..." -ForegroundColor Yellow
Write-Host ""

# Install Sender Service
Write-Host "Installing Sender Service..." -ForegroundColor Yellow
$senderBinPath = "`"$senderPath`""
sc.exe create $senderServiceName binPath= $senderBinPath start= auto DisplayName= "MSMQ Sender Service" obj= "LocalSystem"

if ($LASTEXITCODE -eq 0) {
    # Set description
    sc.exe description $senderServiceName "IIS MSMQ Demo - Sender Application (Port 8081)"
    
    # Grant MSMQ permissions
    Write-Host "  Configuring MSMQ permissions..." -ForegroundColor Gray
    sc.exe privs $senderServiceName SeChangeNotifyPrivilege/SeImpersonatePrivilege/SeCreateGlobalPrivilege
    
    Write-Host "  [OK] Created" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Failed to create service" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Install Receiver Service
Write-Host "Installing Receiver Service..." -ForegroundColor Yellow
$receiverBinPath = "`"$receiverPath`""
# Run as NetworkService instead of LocalSystem for proper MSMQ read permissions
sc.exe create $receiverServiceName binPath= $receiverBinPath start= auto DisplayName= "MSMQ Receiver Service" obj= "NT AUTHORITY\NetworkService"

if ($LASTEXITCODE -eq 0) {
    # Set description
    sc.exe description $receiverServiceName "IIS MSMQ Demo - Receiver Application (Port 8082)"
    
    # Grant MSMQ permissions
    Write-Host "  Configuring MSMQ permissions..." -ForegroundColor Gray
    sc.exe privs $receiverServiceName SeChangeNotifyPrivilege/SeImpersonatePrivilege/SeCreateGlobalPrivilege
    
    # Grant NetworkService explicit permissions to the MSMQ queue
    Write-Host "  Granting NetworkService queue access..." -ForegroundColor Gray
    $queuePath = ".\private$\OrderQueue"
    try {
        # Load MSMQ assembly
        [System.Reflection.Assembly]::LoadWithPartialName("System.Messaging") | Out-Null
        
        # Get the queue
        if ([System.Messaging.MessageQueue]::Exists($queuePath)) {
            $queue = New-Object System.Messaging.MessageQueue($queuePath)
            
            # Grant NetworkService full control
            $queue.SetPermissions("NETWORK SERVICE", [System.Messaging.MessageQueueAccessRights]::FullControl, [System.Messaging.AccessControlEntryType]::Allow)
            Write-Host "  [OK] Queue permissions granted to NetworkService" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Queue doesn't exist yet, permissions will be set when queue is created" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [WARN] Could not set queue permissions: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Queue permissions may need to be set manually" -ForegroundColor Yellow
    }
    
    # Grant NetworkService write permissions to log directory
    Write-Host "  Granting log directory permissions..." -ForegroundColor Gray
    $receiverLogDir = Join-Path (Split-Path $receiverPath) "logs"
    if (-not (Test-Path $receiverLogDir)) {
        New-Item -ItemType Directory -Path $receiverLogDir -Force | Out-Null
    }
    try {
        $acl = Get-Acl $receiverLogDir
        $permission = "NETWORK SERVICE","FullControl","ContainerInherit,ObjectInherit","None","Allow"
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.SetAccessRule($accessRule)
        Set-Acl $receiverLogDir $acl
        Write-Host "  [OK] Log directory permissions granted" -ForegroundColor Green
    } catch {
        Write-Host "  [WARN] Could not set log directory permissions: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    Write-Host "  [OK] Created" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Failed to create service" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Start services
Write-Host "Starting services..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Starting Sender Service..." -ForegroundColor Yellow
Start-Service -Name $senderServiceName
Start-Sleep -Seconds 2
$service = Get-Service -Name $senderServiceName
if ($service.Status -eq "Running") {
    Write-Host "  [OK] Running" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Service status: $($service.Status)" -ForegroundColor Yellow
}

Write-Host ""

Write-Host "Starting Receiver Service..." -ForegroundColor Yellow
Start-Service -Name $receiverServiceName
Start-Sleep -Seconds 2
$service = Get-Service -Name $receiverServiceName
if ($service.Status -eq "Running") {
    Write-Host "  [OK] Running" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Service status: $($service.Status)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "[SUCCESS] Services Installed and Started!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Service Details:" -ForegroundColor Cyan
Write-Host "  Sender Service: $senderServiceName" -ForegroundColor White
Write-Host "  Receiver Service: $receiverServiceName" -ForegroundColor White
Write-Host ""
Write-Host "Applications:" -ForegroundColor Cyan
Write-Host '  Sender:   http://localhost:8081' -ForegroundColor White
Write-Host '  Receiver: http://localhost:8082' -ForegroundColor White
Write-Host ""
Write-Host "Manage Services:" -ForegroundColor Yellow
Write-Host '  View:    services.msc' -ForegroundColor White
Write-Host "  Stop:    Stop-Service $senderServiceName" -ForegroundColor White
Write-Host "  Start:   Start-Service $senderServiceName" -ForegroundColor White
Write-Host "  Status:  Get-Service $senderServiceName" -ForegroundColor White
Write-Host ""
Write-Host "Uninstall:" -ForegroundColor Yellow
Write-Host '  .\install-as-services.ps1 -Uninstall' -ForegroundColor White
Write-Host ""
Write-Host "Test:" -ForegroundColor Yellow
Write-Host '  curl http://localhost:8081/api/order/test' -ForegroundColor White
Write-Host ""


