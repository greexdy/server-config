# 🛠️ PowerShell App Installer

This PowerShell script automates the installation of commonly used applications on Windows using [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/) and chocolatey. Perfect for setting up a new machine or streamlining your workflow.

## 📦 Included Apps

- Google Chrome    
- [uniget](https://github.com/marticliment/UniGetUI)
- VLC Media Player  
- 7zip  
- Notepad++
- teamviewer-host
- advanced IP scanner

## 🚀 How to Use

### 1.
place your .EXE files into the EXE_FILES folder that are not avaible via winget or chocolatey.

### 2.
cd to the directory

```
cd ".\your_path_here"

### 3.
run the code via the following code:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\main_install_script.ps1
