# Run-InstallScript-GUI.ps1
# Simple WinForms GUI to run a PowerShell script, capture output, and optionally run elevated (admin).
# Save this file and run it on Windows. Place your installscript.ps1 in the same folder or browse to it.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Globals
$global:proc = $null
$global:tailJob = $null
$global:logFile = $null

# Helper: append line safely to the multiline textbox from any thread
function Safe-AppendToOutput {
    param($text)
    if ($null -eq $text) { return }
    $action = {
        param($t)
        $txtOutput.AppendText($t + [Environment]::NewLine)
        $txtOutput.SelectionStart = $txtOutput.Text.Length
        $txtOutput.ScrollToCaret()
    }
    $form.BeginInvoke($action, $text) | Out-Null
}

# Create Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Run PowerShell Script - GUI"
$form.Size = New-Object System.Drawing.Size(900,600)
$form.StartPosition = "CenterScreen"

# Script path label + textbox + browse button
$lbl = New-Object System.Windows.Forms.Label
$lbl.Location = New-Object System.Drawing.Point(12,14)
$lbl.Size = New-Object System.Drawing.Size(70,20)
$lbl.Text = "Script:"
$form.Controls.Add($lbl)

$txtScriptPath = New-Object System.Windows.Forms.TextBox
$txtScriptPath.Location = New-Object System.Drawing.Point(90,10)
$txtScriptPath.Size = New-Object System.Drawing.Size(630,24)
$form.Controls.Add($txtScriptPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(730,9)
$btnBrowse.Size = New-Object System.Drawing.Size(70,26)
$btnBrowse.Text = "Browse..."
$form.Controls.Add($btnBrowse)

# Default: script next to this GUI if present
try {
    $defaultCandidate = Join-Path $PSScriptRoot "installscript.ps1"
} catch {
    $defaultCandidate = Join-Path (Get-Location) "installscript.ps1"
}
if (Test-Path $defaultCandidate) {
    $txtScriptPath.Text = (Resolve-Path $defaultCandidate).Path
}

# Run as admin checkbox
$chkAdmin = New-Object System.Windows.Forms.CheckBox
$chkAdmin.Location = New-Object System.Drawing.Point(820,12)
$chkAdmin.Size = New-Object System.Drawing.Size(60,24)
$chkAdmin.Text = "Admin"
$chkAdmin.AutoSize = $true
$form.Controls.Add($chkAdmin)

# Run / Stop buttons
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Location = New-Object System.Drawing.Point(90,46)
$btnRun.Size = New-Object System.Drawing.Size(120,30)
$btnRun.Text = "Run Script"
$form.Controls.Add($btnRun)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Location = New-Object System.Drawing.Point(220,46)
$btnStop.Size = New-Object System.Drawing.Size(120,30)
$btnStop.Text = "Stop"
$btnStop.Enabled = $false
$form.Controls.Add($btnStop)

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Location = New-Object System.Drawing.Point(350,46)
$btnOpenLog.Size = New-Object System.Drawing.Size(140,30)
$btnOpenLog.Text = "Open Log Folder"
$form.Controls.Add($btnOpenLog)

# Clear output button
$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Location = New-Object System.Drawing.Point(500,46)
$btnClear.Size = New-Object System.Drawing.Size(100,30)
$btnClear.Text = "Clear Output"
$form.Controls.Add($btnClear)

# Output textbox
$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(12,88)
$txtOutput.Size = New-Object System.Drawing.Size(860,430)
$txtOutput.Multiline = $true
$txtOutput.ScrollBars = "Both"
$txtOutput.WordWrap = $false
$txtOutput.ReadOnly = $true
$form.Controls.Add($txtOutput)

# Progress bar (informational)
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(12,530)
$progress.Size = New-Object System.Drawing.Size(600,20)
$progress.Style = 'Marquee'
$progress.MarqueeAnimationSpeed = 0
$form.Controls.Add($progress)

# Status label
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(620,530)
$lblStatus.Size = New-Object System.Drawing.Size(250,20)
$lblStatus.Text = "Idle"
$form.Controls.Add($lblStatus)

# Browse action
$btnBrowse.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "PowerShell Scripts|*.ps1|All files|*.*"
    $ofd.InitialDirectory = (Get-Location).Path
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtScriptPath.Text = $ofd.FileName
    }
})

# Open log folder
$btnOpenLog.Add_Click({
    if ($global:logFile -and (Test-Path (Split-Path $global:logFile))) {
        Start-Process -FilePath "explorer.exe" -ArgumentList "/select,`"$global:logFile`""
    } else {
        Start-Process -FilePath "explorer.exe" -ArgumentList (Split-Path -Path $txtScriptPath.Text -ErrorAction SilentlyContinue)
    }
})

# Clear output
$btnClear.Add_Click({
    $txtOutput.Clear()
})

# Helper: tail a log file (reads appended content periodically)
function Start-TailingLog {
    param($path)
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType File -Force | Out-Null
    }
    if ($global:tailJob) {
        # stop previous
        try { Stop-Job $global:tailJob -ErrorAction SilentlyContinue } catch {}
        Remove-Job $global:tailJob -ErrorAction SilentlyContinue
        $global:tailJob = $null
    }
    $pos = 0
    $action = {
        param($file,$interval)
        while ($true) {
            Start-Sleep -Milliseconds $interval
            try {
                $len = (Get-Item $file).Length
                if ($len -gt $pos) {
                    $fs = [System.IO.File]::Open($file,'Open','Read','ReadWrite')
                    try {
                        $fs.Seek($pos, 'Begin') | Out-Null
                        $sr = New-Object System.IO.StreamReader($fs)
                        $text = $sr.ReadToEnd()
                        $sr.Close()
                        $pos = $fs.Position
                    } finally {
                        $fs.Close()
                    }
                    if ($text) {
                        Safe-AppendToOutput $text
                    }
                }
            } catch {
                # ignore transient
            }
        }
    }
    # Start as background job that calls back to GUI via Safe-Append
    $scriptBlock = [scriptblock]::Create($action.ToString() + "`n" + '$args')
    $global:tailJob = Start-Job -ScriptBlock {
        param($file,$interval)
        $pos = 0
        while ($true) {
            Start-Sleep -Milliseconds $interval
            try {
                if (-not (Test-Path $file)) { continue }
                $len = (Get-Item $file).Length
                if ($len -gt $pos) {
                    $fs = [System.IO.File]::Open($file,'Open','Read','ReadWrite')
                    try {
                        $fs.Seek($pos, 'Begin') | Out-Null
                        $sr = New-Object System.IO.StreamReader($fs)
                        $text = $sr.ReadToEnd()
                        $sr.Close()
                        $pos = $fs.Position
                    } finally {
                        $fs.Close()
                    }
                    if ($text) {
                        # Write outputs to job output (the GUI will fetch them)
                        Write-Output $text
                    }
                }
            } catch {
                # ignore
            }
        }
    } -ArgumentList $path,500
    # Monitor the job's output and append to GUI
    Register-ObjectEvent -InputObject $global:tailJob -EventName "StateChanged" -Action {
        # noop
    } | Out-Null
    # Start a timer to poll job output
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 500
    $timer.Add_Tick({
        if ($global:tailJob -and (Get-Job -Id $global:tailJob.Id -State "Running" -ErrorAction SilentlyContinue)) {
            $outs = Receive-Job -Id $global:tailJob.Id -Keep
            if ($outs) {
                Safe-AppendToOutput ($outs -join [Environment]::NewLine)
            }
        } else {
            # job ended
            $timer.Stop()
            $timer.Dispose()
        }
    })
    $timer.Start()
}

# Stop tail and cleanup
function Stop-Tail {
    if ($global:tailJob) {
        try { Stop-Job -Id $global:tailJob.Id -Force -ErrorAction SilentlyContinue } catch {}
        try { Remove-Job -Id $global:tailJob.Id -Force -ErrorAction SilentlyContinue } catch {}
        $global:tailJob = $null
    }
}

# Start non-elevated process and capture output in real-time
function Start-NonElevatedRun {
    param($scriptPath)

    if (-not (Test-Path $scriptPath)) {
        [System.Windows.Forms.MessageBox]::Show("Script not found: $scriptPath","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }

    $lblStatus.Text = "Starting (non-elevated)..."
    $progress.MarqueeAnimationSpeed = 30
    $btnRun.Enabled = $false
    $btnStop.Enabled = $true

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    # -NoProfile -ExecutionPolicy Bypass -File "..."
    $escaped = $scriptPath.Replace('"','\"')
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -ExecutionPolicy Bypass -File `"$escaped`""
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $proc.EnableRaisingEvents = $true

    # Handlers for output and error
    $outHandler = [System.Data.DataReceivedEventHandler]{
        param($sender,$e)
        if ($e.Data) { Safe-AppendToOutput $e.Data }
    }
    $errHandler = [System.Data.DataReceivedEventHandler]{
        param($sender,$e)
        if ($e.Data) { Safe-AppendToOutput $e.Data }
    }

    $proc.add_OutputDataReceived($outHandler)
    $proc.add_ErrorDataReceived($errHandler)

    $global:proc = $proc
    try {
        if ($proc.Start()) {
            $proc.BeginOutputReadLine()
            $proc.BeginErrorReadLine()
            $lblStatus.Text = "Running (non-elevated), PID: $($proc.Id)"
            # Wait async for exit using Register-ObjectEvent
            $ev = Register-ObjectEvent -InputObject $proc -EventName Exited -Action {
                $sproc = $Event.SourceObject
                Safe-AppendToOutput "`nProcess exited with code $($sproc.ExitCode)"
                $form.BeginInvoke({ param($b,$st) $b.Enabled = $st }, $btnRun, $true) | Out-Null
                $form.BeginInvoke({ param($b) $b.Enabled = $false }, $btnStop) | Out-Null
                $form.BeginInvoke({ $progress.MarqueeAnimationSpeed = 0 }) | Out-Null
                $form.BeginInvoke({ $lblStatus.Text = "Idle" }) | Out-Null
                Unregister-Event -SourceIdentifier $Event.SubscriptionId -ErrorAction SilentlyContinue
            }
        } else {
            Safe-AppendToOutput "Failed to start process."
            $btnRun.Enabled = $true
            $btnStop.Enabled = $false
            $progress.MarqueeAnimationSpeed = 0
            $lblStatus.Text = "Idle"
        }
    } catch {
        Safe-AppendToOutput "Error starting process: $_"
        $btnRun.Enabled = $true
        $btnStop.Enabled = $false
        $progress.MarqueeAnimationSpeed = 0
        $lblStatus.Text = "Idle"
    }
}

# Start elevated run: uses a temporary log file and tails it
function Start-ElevatedRun {
    param($scriptPath)

    if (-not (Test-Path $scriptPath)) {
        [System.Windows.Forms.MessageBox]::Show("Script not found: $scriptPath","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }

    $lblStatus.Text = "Starting (elevated)..."
    $progress.MarqueeAnimationSpeed = 30
    $btnRun.Enabled = $false
    $btnStop.Enabled = $true

    # Create a unique log file in TEMP
    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $log = Join-Path $env:TEMP ("installscript_gui_$timestamp.log")
    $global:logFile = $log

    # Argument: run script and redirect all output to log (both stdout and stderr)
    # use *> for PowerShell redirection; but Start-Process + -Verb RunAs interprets arguments as string,
    # so we'll call powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { & 'C:\path\to\script.ps1' *>&1 | Out-File -FilePath 'C:\temp\log.log' -Encoding utf8 }"
    $escapedScript = $scriptPath.Replace("'", "''")
    $escapedLog = $log.Replace("'", "''")
    $command = "& { & '$escapedScript' *>&1 | Out-File -FilePath '$escapedLog' -Encoding utf8 }"
    $arg = "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""

    # Start elevated using Start-Process -Verb RunAs
    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $arg -Verb RunAs
        Safe-AppendToOutput "Started elevated process (output will be written to $log)."
        # Start tailing the log
        Start-TailingLog -path $log
        $lblStatus.Text = "Running elevated (tailing log)"
    } catch {
        Safe-AppendToOutput "Failed to start elevated process: $_"
        $btnRun.Enabled = $true
        $btnStop.Enabled = $false
        $progress.MarqueeAnimationSpeed = 0
        $lblStatus.Text = "Idle"
    }
}

# Stop handler
$btnStop.Add_Click({
    $btnStop.Enabled = $false
    $btnRun.Enabled = $true
    $progress.MarqueeAnimationSpeed = 0
    if ($global:proc -and -not $global:proc.HasExited) {
        try {
            $global:proc.Kill()
            Safe-AppendToOutput "`nProcess killed."
        } catch {
            Safe-AppendToOutput "`nCould not kill process: $_"
        }
    } else {
        # Possibly elevated-run tail job
        Stop-Tail
        Safe-AppendToOutput "`nStopped tailing (if any). If an elevated process is running, please stop it manually."
    }
    $lblStatus.Text = "Stopped"
})

# Run handler
$btnRun.Add_Click({
    $scriptPath = $txtScriptPath.Text.Trim()
    if (-not $scriptPath) {
        [System.Windows.Forms.MessageBox]::Show("Select a script first.","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }
    if (-not (Test-Path $scriptPath)) {
        [System.Windows.Forms.MessageBox]::Show("Script not found: $scriptPath","Error",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        return
    }

    $txtOutput.Clear()
    $lblStatus.Text = "Preparing..."
    $progress.MarqueeAnimationSpeed = 30
    $btnRun.Enabled = $false
    $btnStop.Enabled = $true

    if ($chkAdmin.Checked) {
        Start-ElevatedRun -scriptPath $scriptPath
    } else {
        Start-NonElevatedRun -scriptPath $scriptPath
    }
})

# Form closing cleanup
$form.Add_FormClosing({
    # try stop process / tail
    if ($global:proc -and -not $global:proc.HasExited) {
        try { $global:proc.Kill() } catch {}
    }
    Stop-Tail
})

# Show the form (blocking)
[void]$form.ShowDialog()
