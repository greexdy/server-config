# 🛠️ PowerShell App Installer

This PowerShell script automates the installation of commonly used applications on Windows using [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) and [Chocolatey](https://chocolatey.org/). It's perfect for setting up a new machine or streamlining your workflow.

## 📦 Included Apps

- Google Chrome  
- [UniGetUI](https://github.com/marticliment/UniGetUI)  
- VLC Media Player  
- 7-Zip  
- Notepad++  
- TeamViewer Host  
- Advanced IP Scanner

## 🚀 How to Use

### 1. Add Custom EXE Files
Place any .EXE files that are **not available via winget or Chocolatey** into the `EXE_FILES` folder inside `APPS`.

### 2. Open PowerShell and Navigate to the Script Folder
```powershell
cd "path\to\server-config"
```

### 3. Run the Installer Script
Set the execution policy (if needed) and run the main install script:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
./main_install_script.ps1
```
.\main_install_script.ps1
