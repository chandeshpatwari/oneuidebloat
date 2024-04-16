# Setting Background and Text color
$Host.UI.RawUI.BackgroundColor = 'Black'; $Host.UI.RawUI.ForegroundColor = 'White'; $ProgressPreference = 'SilentlyContinue'; Clear-Host
$tmpDirectory = "$Env:TEMP\Temp"; New-Item -Path $tmpDirectory -Force -ItemType Directory | Out-Null

# Remove Function
function RemoveADB {
  $isinstalled = Get-Command -Name 'adb.exe' -ErrorAction SilentlyContinue
  if ($isInstalled) {
    $Installdir = $isinstalled.source | Split-Path -Parent
    $installedusingwinget = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\WinGet\Packages\Google.PlatformTools_*'
    if (Test-Path $installedusingwinget) {
      if (Get-Command winget.exe) { Write-Host 'Uninstalling using winget'; winget uninstall 'Google.PlatformTools' }
    }
    if (Test-Path $Installdir) {
      Write-Host 'Removing Platform Tools...'
      adb kill-server 2>&1 | Out-Null; Remove-Item -Path ($Installdir | Split-Path -Parent) -Recurse -Force
      # Removing From Path Variable
      $currentPath = ([Environment]::GetEnvironmentVariable('Path', 'User') -replace ';;+', ';').TrimEnd(';')
      if ($currentPath.Split(';') -contains $Installdir) {
        $newPath = $currentPath.Replace($Installdir, ''); [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        $env:Path = "$newPath"
      }
      if ((Read-Host 'ADB removed. Verify?').ToLower() -eq 'y') { rundll32 sysdm.cpl, EditEnvironmentVariables }
    }       
  } else { Write-Host 'ADB not found.'; Pause; return }
}

# Check Version Function
function GetDownloadVersion {
  $version = Invoke-Command -ScriptBlock { & "$SourceDir\adb.exe" --version }
  $latestVersion = [version](([regex]::Matches($version[1], '(\d+(\.\d+){2})')).Value)
  return $latestVersion
}
function GetInstalledVersion {
  $version = adb --version
  $installedVersion = [version](([regex]::Matches($version[1], '(\d+(\.\d+){2})')).Value)
  return $installedVersion
}

# Download & Copy Function
function FetchLatest($URL, $DownloadFile, $ExtractionDir) {
  Start-BitsTransfer -Source $URL -Destination $DownloadFile -EA SilentlyContinue -WA SilentlyContinue
  if (Test-Path $DownloadFile) { Expand-Archive -Path $DownloadFile -DestinationPath $ExtractionDir -Force; return 200 }
  else { Write-Host 'Error Downloading' -ForegroundColor Red ; return 404 }
}

function Install($SourceDir, $InstallDir) {
  New-Item $InstallDir -ItemType Directory -ErrorAction SilentlyContinue
  Copy-Item -Path $SourceDir -Recurse -Destination $InstallDir -Force -Verbose
}

# Install, Set to Path, Update
function SetToPath {
  $currentPath = ([Environment]::GetEnvironmentVariable('Path', 'User') -replace ';;+', ';').TrimEnd(';')
  $installPath = Join-Path -Path $Installdir -ChildPath 'platform-tools'
  if ($currentPath.Split(';') -contains $installPath) {
    Write-Host 'The path' "$installPath" 'is already in the user path variable'
  } else {
    $newPath = "$currentPath;$installPath;"
    (Get-ItemProperty -Path 'HKCU:\Environment' -Name 'Path').Path | Out-File $env:USERPROFILE\Downloads\userpath.txt -Append
    [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User'); $env:Path = "$installPath;$env:Path"
  }
}


function Update($SourceDir) {
  $installedVersion = GetInstalledVersion; $latestVersion = GetDownloadVersion
  if ($latestVersion -gt $installedVersion) {
    Write-Output "Update available. Latest Version: $latestVersion. Installed Version: $installedVersion"
    $InstallDir = $isinstalled.Source | Split-Path -Parent | Split-Path -Parent
    Install -SourceDir $SourceDir -InstallDir $InstallDir
  } elseif ($latestVersion -eq $installedVersion) { Write-Output "Latest Version: $latestVersion installed" }
  else { Write-Output 'Error retrieving ADB version.' }
}

# Main
function Main {
  $downloadurl = 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'
  $destination = "$tmpDirectory\platform-tools-latest-windows.zip"
  $SourceDir = "$tmpDirectory\platform-tools"
  $InstallDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'google.platformtools'

  $isinstalled = Get-Command -Name 'adb.exe' -ErrorAction SilentlyContinue 
  $usewinget = if (Get-Command winget.exe) { (Read-Host 'Use winget?').ToLower() -eq 'y' } else { $false }

  if (!($isinstalled)) {
    Write-Host 'Installing Platform Tools...'
    if ($usewinget) { winget Install 'Google.PlatformTools' }
    else { $DownloadStatus = FetchLatest -URL $downloadurl -DownloadFile $destination -ExtractionDir $tmpDirectory; if ( $DownloadStatus -eq '200') { Install -SourceDir $SourceDir -InstallDir $InstallDir; SetToPath } }
  } elseif ($isinstalled) {
    Write-Host 'Checking for Update...'
    if ($usewinget) { winget Update 'Google.PlatformTools' }
    else { $DownloadStatus = FetchLatest -URL $downloadurl -DownloadFile $destination -ExtractionDir $tmpDirectory ; if ( $DownloadStatus -eq '200') { Update -SourceDir $SourceDir } }
  }
}

# Main menu loop
do {
  Clear-Host
  Write-Output 'Select an option:'
  Write-Output '1. Install/Update Platform Tools'
  Write-Output '2. Remove Platform Tools'
  Write-Output '3. Check Path Variables'
  Write-Output '4. Clear & Exit'

  switch (Read-Host 'Enter your choice (1-4)') {
    1 { Main; Pause }
    2 { RemoveADB ; Pause }
    3 { rundll32 sysdm.cpl, EditEnvironmentVariables }
    4 { Remove-Item -Recurse -Force $tmpDirectory; exit }
    default {
      Write-Output 'Invalid choice. Please try again.'; Read-Host 'Press Enter to continue'
    }
  }
} while ($choice -ne '4')