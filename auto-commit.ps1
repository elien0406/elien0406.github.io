$ErrorActionPreference = "Stop"

$RepoPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$Git = "C:\Program Files\Git\cmd\git.exe"
$DelaySeconds = 5

if (-not (Test-Path $Git)) {
  Write-Host "Git not found: $Git"
  exit 1
}

function Invoke-AutoCommit {
  Push-Location $RepoPath
  try {
    $status = & $Git status --porcelain
    if (-not $status) {
      return
    }

    & $Git add -A
    $message = "Auto update $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    & $Git commit -m $message
    & $Git push
  }
  finally {
    Pop-Location
  }
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $RepoPath
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, DirectoryName, LastWrite, Size'

$timer = New-Object Timers.Timer
$timer.Interval = $DelaySeconds * 1000
$timer.AutoReset = $false

Register-ObjectEvent $timer Elapsed -Action {
  Invoke-AutoCommit
} | Out-Null

$action = {
  if ($Event.SourceEventArgs.FullPath -match '\\.git\\') {
    return
  }

  $timer.Stop()
  $timer.Start()
}

Register-ObjectEvent $watcher Created -Action $action | Out-Null
Register-ObjectEvent $watcher Changed -Action $action | Out-Null
Register-ObjectEvent $watcher Deleted -Action $action | Out-Null
Register-ObjectEvent $watcher Renamed -Action $action | Out-Null

Write-Host "Auto commit watcher is running for: $RepoPath"
Write-Host "Changes will be committed and pushed after $DelaySeconds seconds."
Invoke-AutoCommit

while ($true) {
  Start-Sleep -Seconds 1
}
