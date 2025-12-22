# Deploying from Mac to Windows VM

Since **System.Messaging is Windows-only**, you need to build on Windows. Here's the fastest way:

---

## 🚀 Fastest Method: GitHub → Windows VM

### Step 1: Push to GitHub (On Mac - 2 minutes)

```bash
cd "/Users/matthew.ruyffelaert/Library/CloudStorage/GoogleDrive-matthew.ruyffelaert@datadoghq.com/My Drive/1Learning/IIS MSMQ"

# Initialize git (if not already)
git init

# Add all files
git add .

# Commit
git commit -m "IIS MSMQ Demo - Ready for Windows"

# Push to your GitHub (create a repo first)
git remote add origin https://github.com/YOUR-USERNAME/iis-msmq-demo.git
git branch -M main
git push -u origin main
```

### Step 2: Clone on Windows VM (2 minutes)

```powershell
# On Windows VM
cd C:\
git clone https://github.com/YOUR-USERNAME/iis-msmq-demo.git
cd iis-msmq-demo

# Install MSMQ
.\setup-msmq.ps1

# Build (fast - takes ~10 seconds)
dotnet restore
dotnet build -c Release

# Run
.\run-applications.ps1
```

**Total Time**: ~4 minutes

---

## 🔄 Alternative: Direct Transfer (No GitHub)

### Option A: Cloud Storage

1. **Zip on Mac**:
   ```bash
   cd "/Users/matthew.ruyffelaert/Library/CloudStorage/GoogleDrive-matthew.ruyffelaert@datadoghq.com/My Drive/1Learning"
   zip -r iis-msmq-source.zip "IIS MSMQ"
   
   # Upload to Dropbox/OneDrive/Google Drive shared link
   ```

2. **Download on Windows**:
   - Download the zip
   - Extract to `C:\Projects\IIS-MSMQ`
   - Run setup script

### Option B: Parallels Shared Folder

```powershell
# On Windows VM with Parallels shared folders enabled
cd C:\
xcopy "\\Mac\Home\Library\CloudStorage\GoogleDrive-matthew.ruyffelaert@datadoghq.com\My Drive\1Learning\IIS MSMQ" "C:\Projects\IIS-MSMQ" /E /I /Y

cd C:\Projects\IIS-MSMQ

# Setup, build, run
.\setup-msmq.ps1
dotnet restore
dotnet build -c Release
.\run-applications.ps1
```

### Option C: Azure VM (RDP Copy/Paste)

1. **On Mac**: Select all files in Finder, copy (Cmd+C)
2. **On Windows VM**: Via Microsoft Remote Desktop, paste into folder
3. Build and run

---

## ⚡ One-Command Setup on Windows

Once files are on Windows VM, run this **ONE command**:

```powershell
# This does EVERYTHING: Setup MSMQ, restore, build, and run
.\build-and-run.ps1
```

That's it! The script will:
1. ✅ Setup MSMQ (if admin)
2. ✅ Restore NuGet packages (~5 seconds)
3. ✅ Build the solution (~10 seconds)
4. ✅ Start both applications

**Total build time on Windows**: ~15 seconds

---

## 📊 Comparison of Methods

| Method | Transfer Time | Setup Time | Total | Notes |
|--------|--------------|------------|-------|-------|
| **GitHub** | 2 min | 15 sec | ~2.5 min | Best for multiple deployments |
| **Parallels Shared** | Instant | 15 sec | ~15 sec | Fastest if using Parallels |
| **Cloud Storage** | 3 min | 15 sec | ~3.5 min | Good if no git |
| **RDP Copy/Paste** | 1 min | 15 sec | ~1.5 min | Good for Azure VM |

---

## 🎯 Recommended Approach

### If You Have Parallels:
```bash
# On Mac - Do nothing, files already shared!

# On Windows VM:
cd C:\
xcopy "\\Mac\Home\Library\CloudStorage\GoogleDrive-matthew.ruyffelaert@datadoghq.com\My Drive\1Learning\IIS MSMQ" "C:\Projects\IIS-MSMQ" /E /I /Y
cd C:\Projects\IIS-MSMQ
.\build-and-run.ps1
```

**Total Time**: < 1 minute

### If Using GitHub (Best for Reusability):
```bash
# On Mac (one time):
cd "/Users/matthew.ruyffelaert/Library/CloudStorage/GoogleDrive-matthew.ruyffelaert@datadoghq.com/My Drive/1Learning/IIS MSMQ"
git init
git add .
git commit -m "IIS MSMQ Demo"
git remote add origin https://github.com/YOUR-USERNAME/iis-msmq-demo.git
git push -u origin main

# On any Windows VM (forever):
git clone https://github.com/YOUR-USERNAME/iis-msmq-demo.git
cd iis-msmq-demo
.\build-and-run.ps1
```

**Total Time**: 2-3 minutes (reusable forever)

---

## 🔍 Why Can't We Build on Mac?

**System.Messaging** is a Windows-only library that:
- Only exists on Windows
- Requires MSMQ runtime to be present
- Has no cross-platform equivalent in .NET

Even though we target `win-x64`, the compiler still tries to resolve the Windows-only APIs during build, which fails on Mac/Linux.

**Solution**: Build on Windows VM (takes only 15 seconds)

---

## 📦 What Gets Transferred

File structure (what you're copying):
```
IIS MSMQ/
├── SenderWebApp/          (~50 KB source)
├── ReceiverWebApp/        (~50 KB source)
├── *.ps1 scripts          (~20 KB)
├── *.md documentation     (~100 KB)
└── *.sln, *.csproj        (~10 KB)

Total: ~230 KB (tiny!)
```

After build on Windows:
```
+ bin/                     (~10 MB compiled)
+ obj/                     (~5 MB temp)

Total after build: ~15 MB
```

---

## 🚀 Quick Deploy Cheatsheet

### Method 1: Parallels (Fastest)
```powershell
xcopy "\\Mac\..." "C:\IIS-MSMQ" /E /I /Y
cd C:\IIS-MSMQ
.\build-and-run.ps1
```

### Method 2: GitHub (Most Reusable)
```powershell
git clone https://github.com/YOUR-REPO/iis-msmq-demo.git
cd iis-msmq-demo
.\build-and-run.ps1
```

### Method 3: Manual Zip
```powershell
# Extract zip to C:\IIS-MSMQ
cd C:\IIS-MSMQ
.\build-and-run.ps1
```

---

## ⚙️ Advanced: If Build is Slow

On a fast Windows machine, the full build (restore + compile) takes ~15 seconds.

If it's slower on your VM:
1. **Allocate more RAM** to VM (8GB recommended)
2. **Allocate more CPU cores** (4 cores recommended)
3. **Disable Windows Defender** temporarily during build
4. **Use SSD storage** in VM settings

---

## ✅ Validation Checklist

After deployment:

```powershell
# 1. Check apps are running
curl http://localhost:8081/
curl http://localhost:8082/

# 2. Send a test order
curl http://localhost:8081/api/order/test

# 3. Run full test suite
.\test-system.ps1
```

---

## 🐛 Troubleshooting

### "dotnet: command not found"
Install .NET 8.0 SDK: https://dotnet.microsoft.com/download/dotnet/8.0

### "MSMQ service not running"
```powershell
Start-Service MSMQ
# Or run: .\setup-msmq.ps1 as Administrator
```

### "Port already in use"
Edit `appsettings.json` in each app to change ports

### Build errors
```powershell
# Clean and rebuild
dotnet clean
dotnet restore --force
dotnet build -c Release
```

---

## 📝 Summary

**You cannot build on Mac** because System.Messaging is Windows-only.

**Best approach**:
1. Push source code to GitHub from Mac (or use shared folder)
2. Clone/copy to Windows VM
3. Run `.\build-and-run.ps1` (one command)
4. Done in ~15 seconds!

The build is so fast on Windows that pre-building is unnecessary. Just transfer the source and build there! 🚀

