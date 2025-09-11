Clear-Host
Write-Host ""
Write-Host "========================================================"
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host '      ____   _   _   ___  ' -ForegroundColor Red
Write-Host '     | ___ \_   _/  ___|  ' -ForegroundColor Red
Write-Host '     | |_/ / | | \ `--.   ' -ForegroundColor Red
Write-Host '     |    /  | |  `--. \  ' -ForegroundColor Red
Write-Host '     | |\ \  | | /\__/ /  ' -ForegroundColor Red
Write-Host '     \_| \_| \_/ \____/    ' -ForegroundColor Red
Write-Host ""
Write-Host '     RTS Package Installer Script V1.0' -ForegroundColor Red
Write-Host '     Created by Brecht Bondue ' -ForegroundColor Red
Write-Host ""
Write-Host ""
Write-Host ""
Write-Host 'NOTES:' -ForegroundColor blue
Write-Host ""
Write-Host "========================================================"
Write-Host ""
Write-Host "NOTES:" -ForegroundColor blue
Write-Host "  - The install process will not be as reliable as importing a bundle with UniGetUI. Expect issues and errors." -ForegroundColor Yellow
Write-Host "  - Packages will be installed with the install options specified at the time of creation of this script." -ForegroundColor Yellow
Write-Host "  - Error/Sucess detection may not be 100% accurate." -ForegroundColor Yellow
Write-Host "  - Some of the packages may require elevation. Some of them may ask for permission, but others may fail. Consider running this script elevated." -ForegroundColor Yellow
Write-Host "  - You can skip confirmation prompts by running this script with the parameter `/DisablePausePrompts` " -ForegroundColor Yellow
Write-Host ""
Write-Host ""
if ($args[0] -ne "/DisablePausePrompts") { pause }
Write-Host ""
Write-Host "This script will attempt to install the following packages:"
Write-Host "  - UniGetUI (formerly WingetUI) from WinGet"
Write-Host "  - Google Chrome For Enterprise from Chocolatey"
Write-Host "  - Teamviewer.host from Chocolatey"
Write-Host "  - Advanced Ip Scanner from Chocolatey"
Write-Host "  - Notepadplusplus from Chocolatey"
Write-Host "  - 7zip from Chocolatey"
Write-Host ""
if ($args[0] -ne "/DisablePausePrompts") { pause }
Clear-Host

$success_count=0
$failure_count=0
$commands_run=0
$results=""

$commands= @(
    'cmd.exe /C winget.exe install --id "MartiCliment.UniGetUI" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force',
    'cmd.exe /C winget.exe install --id "TeamViewer.TeamViewer.Host" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force',
    'cmd.exe /C winget.exe install --id "Notepad++.Notepad++" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force',
    'cmd.exe /C winget.exe install --id "Google.Chrome" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force',
    'cmd.exe /C winget.exe install --id "7zip.7zip" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force',
    'cmd.exe /C winget.exe install --id "Famatech.AdvancedIPScanner" --exact --source winget --accept-source-agreements --disable-interactivity --silent --accept-package-agreements --force'
)


foreach ($command in $commands) {
    Write-Host "Running: $command" -ForegroundColor Yellow
    cmd.exe /C $command
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[  OK  ] $command" -ForegroundColor Green
        $success_count++
        $results += "$([char]0x1b)[32m[  OK  ] $command`n"
    }
    else {
        Write-Host "[ FAIL ] $command" -ForegroundColor Red
        $failure_count++
        $results += "$([char]0x1b)[31m[ FAIL ] $command`n"
    }
    $commands_run++
    Write-Host ""
}

Write-Host "========================================================"
Write-Host "                  OPERATION SUMMARY"
Write-Host "========================================================"
Write-Host "Total commands run: $commands_run"
Write-Host "Successful: $success_count"
Write-Host "Failed: $failure_count"
Write-Host ""
Write-Host "Details:"
Write-Host "$results$([char]0x1b)[37m"
Write-Host "========================================================"

if ($failure_count -gt 0) {
    Write-Host "Some commands failed. Please check the log above." -ForegroundColor Yellow
}
else {
    Write-Host "All commands executed successfully!" -ForegroundColor Green
}
Write-Host ""
if ($args[0] -ne "/DisablePausePrompts") { pause }
exit $failure_count