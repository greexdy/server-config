# 🛠️ PowerShell App Installer

This PowerShell script automates the installation of commonly used applications on Windows using [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/). Perfect for setting up a new machine or streamlining your workflow.

## 📦 Included Apps

- Google Chrome  
- Mozilla Firefox  
- Visual Studio Code  
- Git  
- Discord  
- VLC Media Player  
- 7zip  
- Notepad++

## 🚀 How to Use

### 1.
Simply run the following code.

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install-apps.ps1
