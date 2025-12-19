# Running MSMQ Demo on Windows VM from Mac

This guide explains how to run the IIS MSMQ sandbox on a Windows VM when you're working from a Mac.

---

## Option A: Parallels Desktop (Recommended if you have it)

### Setup (One-time)

1. **Install Parallels Desktop**
   - Available from [parallels.com](https://www.parallels.com)
   - Or install Windows 11 ARM on Apple Silicon

2. **Create/Start Windows VM**
   - Launch Parallels
   - Create new Windows 10/11 VM if needed
   - Start the VM

3. **Enable Shared Folders**
   - Parallels → Configure → Options → Shared Folders
   - Enable "Share Mac folders with Windows"
   - Your Google Drive will be accessible at: `\\Mac\Home\Library\CloudStorage\...`

### Transfer Files

**Option 1: Access via Shared Folder** (Easiest)
```powershell
# In Windows VM, copy to local drive:
cd C:\
mkdir Projects
xcopy "\\Mac\Home\Library\CloudStorage\GoogleDrive-matthew.ruyffelaert@datadoghq.com\My Drive\1Learning\IIS MSMQ" "C:\Projects\IIS-MSMQ" /E /I
cd C:\Projects\IIS-MSMQ
```

**Option 2: Drag & Drop**
- Parallels supports drag & drop
- Just drag the entire "IIS MSMQ" folder from Finder to Windows Desktop
- Then copy to `C:\Projects\IIS-MSMQ`

### Install Prerequisites (In Windows VM)

```powershell
# 1. Install .NET 8.0 SDK
# Download from: https://dotnet.microsoft.com/download/dotnet/8.0
# Or use winget:
winget install Microsoft.DotNet.SDK.8

# 2. Verify installation
dotnet --version
# Should show 8.x.x
```

### Run the Sandbox

```powershell
# Open PowerShell as Administrator
cd C:\Projects\IIS-MSMQ

# Setup MSMQ
.\setup-msmq.ps1

# Build and run
dotnet restore
dotnet build
.\run-applications.ps1
```

### Access from Mac

Parallels creates a shared network. From your **Mac browser**, access:
- Sender App: `http://windows.local:5001`
- Receiver App: `http://windows.local:5002`

Or find the Windows VM IP:
```powershell
# In Windows VM:
ipconfig
# Look for "Ethernet adapter Ethernet"
# Use that IP, e.g., http://10.211.55.3:5001
```

---

## Option B: UTM (Free, Apple Silicon)

### Setup

1. **Install UTM**
   ```bash
   brew install utm
   # Or download from: https://mac.getutm.app
   ```

2. **Download Windows 11 ARM ISO**
   - Get from Microsoft Insider Program (free)
   - Or use Windows 11 evaluation ISO

3. **Create VM in UTM**
   - New VM → Virtualize → Windows
   - Allocate 4GB RAM minimum
   - 50GB disk space
   - Follow setup wizard

### Transfer Files

**Option 1: Network Share**
```bash
# On Mac, enable File Sharing in System Settings
# In Windows VM, map network drive:
# \\YOUR-MAC-IP\SharedFolder
```

**Option 2: Cloud Sync**
```powershell
# In Windows VM, install Google Drive Desktop
# Download from: https://www.google.com/drive/download/
# Sign in and sync your folder
```

**Option 3: ZIP Transfer**
```bash
# On Mac:
cd "~/Library/CloudStorage/GoogleDrive-matthew.ruyffelaert@datadoghq.com/My Drive/1Learning"
zip -r iis-msmq.zip "IIS MSMQ"

# Upload to cloud storage or use USB pass-through in UTM
# Then extract in Windows VM
```

### Access from Mac

Find Windows VM IP:
```powershell
# In Windows VM:
ipconfig
```

Then from Mac browser: `http://<VM-IP>:5001`

---

## Option C: Azure/AWS Cloud VM

### Quick Azure Setup from Mac

```bash
# Install Azure CLI
brew install azure-cli

# Login
az login

# Create resource group
az group create --name msmq-demo --location eastus

# Create Windows VM
az vm create \
  --resource-group msmq-demo \
  --name msmq-sandbox \
  --image Win2019Datacenter \
  --size Standard_D2s_v3 \
  --admin-username azureuser \
  --admin-password 'YourSecurePassword123!'

# Open RDP port
az vm open-port --resource-group msmq-demo --name msmq-sandbox --port 3389

# Get public IP
az vm show -d --resource-group msmq-demo --name msmq-sandbox --query publicIps -o tsv
```

### Connect from Mac

```bash
# Install Microsoft Remote Desktop from Mac App Store
# Or:
brew install --cask microsoft-remote-desktop

# Open Microsoft Remote Desktop
# Add PC with the public IP from Azure
# Connect with azureuser and your password
```

### Transfer Files to Azure VM

**Option 1: RDP Copy/Paste** (Easiest)
- Microsoft Remote Desktop supports clipboard
- Copy text/small files directly

**Option 2: Git**
```powershell
# In Azure Windows VM:
# Install git: https://git-scm.com/download/win

# Create a temporary git repo on Mac
cd "~/Library/CloudStorage/GoogleDrive-matthew.ruyffelaert@datadoghq.com/My Drive/1Learning/IIS MSMQ"
git init
git add .
git commit -m "Initial commit"

# Push to GitHub (private repo)
# Then clone in Windows VM
```

**Option 3: OneDrive/Dropbox**
- Upload folder to OneDrive
- Download in Windows VM

### Open Ports for Testing

```bash
# Allow HTTP access to apps
az vm open-port --resource-group msmq-demo --name msmq-sandbox --port 5001 --priority 1001
az vm open-port --resource-group msmq-demo --name msmq-sandbox --port 5002 --priority 1002

# Now access from Mac browser using public IP:
# http://<PUBLIC-IP>:5001
```

---

## Recommended Workflow

### Best Setup for Demo Purposes

1. **Parallels Desktop** (if you have it)
   - Fastest setup
   - Best integration with macOS
   - Drag & drop files
   - Shared clipboard
   - Access apps from Mac browser

2. **Azure VM** (if no local VM)
   - Quick to spin up (5 minutes)
   - Access from anywhere
   - Easy to share with others
   - Pay only when running

---

## Step-by-Step: First Time Setup

### Once in Windows VM:

```powershell
# 1. Open PowerShell as Administrator
# Right-click PowerShell icon → Run as Administrator

# 2. Navigate to project folder
cd C:\Projects\IIS-MSMQ  # or wherever you copied files

# 3. Install MSMQ
.\setup-msmq.ps1
# May require restart - if so, restart VM and continue

# 4. Install .NET SDK (if not already)
# Download from: https://dotnet.microsoft.com/download/dotnet/6.0

# 5. Build the solution
dotnet restore
dotnet build

# 6. Run the applications
.\run-applications.ps1

# Two new PowerShell windows will open showing the apps running
```

### Test from Mac

```bash
# Find Windows VM IP (from Windows VM):
ipconfig

# Then from Mac terminal:
curl http://<VM-IP>:5001/api/order/test
curl http://<VM-IP>:5002/api/status/health

# Or open in Mac browser:
open http://<VM-IP>:5001/swagger
```

---

## Networking Tips

### Firewall Configuration (if needed)

If you can't access apps from Mac:

```powershell
# In Windows VM, allow ports:
New-NetFirewallRule -DisplayName "MSMQ Sender" -Direction Inbound -LocalPort 5001 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "MSMQ Receiver" -Direction Inbound -LocalPort 5002 -Protocol TCP -Action Allow
```

### Port Forwarding (Parallels)

If using shared network:
- Parallels → Configure → Hardware → Network
- Change to "Bridged Network" for direct IP access

---

## Development Workflow

### Recommended Setup:

1. **Edit code on Mac**
   - Use VS Code on Mac
   - Edit files in Google Drive folder
   - Files auto-sync to Windows via Parallels shared folders

2. **Run in Windows VM**
   - Keep PowerShell windows open in VM
   - Apps reload on file changes (hot reload)

3. **Test from Mac**
   - Use Mac browser
   - Use Postman on Mac
   - Access Windows VM apps via network

### Quick Restart

```powershell
# In Windows VM, stop apps (Ctrl+C in both PowerShell windows)
# Then restart:
.\run-applications.ps1
```

---

## Troubleshooting

### Can't access apps from Mac browser

1. **Check Windows IP**:
   ```powershell
   ipconfig
   ```

2. **Check Windows Firewall**:
   ```powershell
   # Temporarily disable to test:
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
   
   # If it works, re-enable and add rules:
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
   New-NetFirewallRule -DisplayName "MSMQ Apps" -Direction Inbound -LocalPort 5001,5002 -Protocol TCP -Action Allow
   ```

3. **Check apps are running**:
   ```powershell
   # In Windows VM:
   netstat -ano | findstr "5001"
   netstat -ano | findstr "5002"
   ```

### Shared folders not working (Parallels)

1. Install Parallels Tools in Windows VM
2. Restart Windows VM
3. Check Parallels → Configure → Options → Shared Folders

### Performance issues

1. **Allocate more RAM to VM**:
   - Recommended: 4GB minimum
   - Better: 8GB

2. **Allocate more CPU cores**:
   - Recommended: 2 cores minimum
   - Better: 4 cores

---

## Cost Optimization (Cloud VMs)

### Azure VM Costs

**Standard_D2s_v3** (recommended):
- 2 vCPUs, 8GB RAM
- ~$70/month if running 24/7
- ~$0.10/hour

**To minimize costs**:
```bash
# Stop VM when not in use:
az vm deallocate --resource-group msmq-demo --name msmq-sandbox

# Start when needed:
az vm start --resource-group msmq-demo --name msmq-sandbox

# Delete when done:
az group delete --name msmq-demo --yes
```

### AWS EC2 Costs

**t3.medium** (similar specs):
- ~$30-40/month
- Stop instance when not using

---

## Quick Reference

| Task | Command |
|------|---------|
| **Find Windows IP** | `ipconfig` (in VM) |
| **Start apps** | `.\run-applications.ps1` |
| **Test from Mac** | `curl http://<VM-IP>:5001/api/order/test` |
| **Stop apps** | Ctrl+C in PowerShell windows |
| **Restart MSMQ** | `Restart-Service MSMQ` (as Admin) |
| **Check MSMQ** | `Get-Service MSMQ` |

---

## Best VM for Different Scenarios

| Scenario | Best Option | Why |
|----------|-------------|-----|
| Daily development | Parallels | Fast, integrated, local |
| Quick demo | Azure VM | Fast setup, accessible anywhere |
| Long-term testing | Parallels/UTM | No ongoing costs |
| Team collaboration | Azure VM | Easy to share access |
| Apple Silicon Mac | UTM or Parallels | Native ARM support |
| Intel Mac | Any option | All work well |

---

## Files Location in Different Setups

### Parallels:
```
Windows: C:\Projects\IIS-MSMQ\
Mac: ~/Library/CloudStorage/.../IIS MSMQ/
Shared: \\Mac\Home\Library\CloudStorage\.../IIS MSMQ\
```

### UTM:
```
Windows: C:\Projects\IIS-MSMQ\
(Need to manually transfer files)
```

### Azure VM:
```
Windows: C:\Projects\IIS-MSMQ\
(Access via RDP only)
```

---

## Summary

**Easiest Path:**
1. Use Parallels Desktop (if available)
2. Share Mac folders with Windows
3. Copy files to C:\ in Windows
4. Run setup scripts
5. Access from Mac browser

**Alternative:**
1. Spin up Azure Windows VM
2. Transfer files via RDP copy/paste
3. Run setup scripts
4. Access via public IP

Both work great - choose based on what you already have! 🚀

