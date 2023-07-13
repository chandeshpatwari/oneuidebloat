$host.ui.rawui.BackgroundColor = "Black"
$host.ui.rawui.ForegroundColor = "White"

# Check ADB
if (!(adb.exe)) { "adb not installed"; return }

#  Start the ADB server
adb start-server

# Retrieve the list of connected devices
$devOutput = adb devices -l | Select-Object -Skip 1 | Select-Object -SkipLast 1
$devOutput = @($devOutput)

# Function to select a device from the list
function SelectDevice {
  $index = 0
  foreach ($dev in $devOutput) {
    Write-Host "[$index]. $dev"
    $index++
  }

  $devindex = Read-Host "Select Device Index"

  while ($devindex -gt ($devOutput.Count - 1)) {
    $devindex = Read-Host "Invalid device index. Select Device Index"
  }

  return $devindex
}

# Check the count of connected devices
if ($devOutput.Count -eq 0) {
  Write-Host "No devices found"
  return
} else {
  $devindex = SelectDevice
}

$devSelect = $devOutput[$devindex]

# Check the selected device status
if ($devSelect.Contains("device")) {
  Write-Host "Device Connected"
} elseif ($devSelect.Contains("unauthorized")) {
  Write-Host "Allow USB Debugging"
  adb reconnect offline
  Start-Sleep 5
}

# Retrieve the device list again after potential reconnection
$devOutput = adb devices -l | Select-Object -Skip 1 | Select-Object -SkipLast 1
$devOutput = @($devOutput)
$selectedDevice = $devOutput[$devindex] -split '\s+'

# Check the selected device status again
if ($selectedDevice.Contains("device")) {
  $DevSID = $selectedDevice[0]
  Pause
} else {
  Write-Host "Failed to connect to the device. Connect manually?"
  notepad.exe .\adb_connect.txt
  adb kill-server
  return
}

##

# Function to retrieve user information
function Get-Users {
  $usersOutput = adb -s $DevSID shell pm list users
  $userInfoRegex = "UserInfo{(\d+):\s*([\w\s]+)\s*:(\w+)}"
  $nameIdMatch = [regex]::Matches($usersOutput, $userInfoRegex)
  
  $userObjects = foreach ($match in $nameIdMatch) {
    [PSCustomObject]@{
      UserID   = $match.Groups[1].Value
      Username = $match.Groups[2].Value.Trim()
      UniqueID = $match.Groups[3].Value.Trim()
    }
  }
  
  return $userObjects
}

# Retrieve User IDs.
$userObjects = Get-Users
$MultiUsers = $userObjects | Where-Object { $_.UniqueID -notin "1030", "10b0" -and $_.Username -notin "DUAL_APP", "Secure Folder" }
$MainUsers = $userObjects | Where-Object { $_.UniqueID -eq "c13" }

# Gives Option to Choose Users, if multiuser available
function ChooseUsers {
  $selectedIndexes = $MultiUsers.ForEach({
      $index = $MultiUsers.IndexOf($_)
      Write-Host "[$index]. UserID: $($_.UserID), Username: $($_.Username), UniqueID: $($_.UniqueID)"
      $index
    })

  do {
    $selectedUserIndexes = Read-Host "Enter the User ID(s) Index, comma-separated."
    $selectedIndexesArray = $selectedUserIndexes -split ',' -match '\d+' | ForEach-Object { [int]$_ } | Where-Object { $selectedIndexes -contains $_ } | Sort-Object -Unique
  } while ($null -eq $selectedIndexesArray)
  
  $MainUsers = $MultiUsers[$selectedIndexesArray]
  return $MainUsers
}


if ($MultiUsers.Count -ge 2) { $MainUsers = ChooseUsers }
$UserIDs = $MainUsers.UserID
if (!$UserIDs) { Write-Host "No Profile Found"; break }

# Function to display the menu
function Show-Menu {
  Clear-Host
  Write-Host "==== Debloat Menu ===="
  Write-Host "1. Auto Debloat(2,4,3)" -ForegroundColor Green
  Write-Host "2. Restore Uninstalled Apps" -ForegroundColor Green
  Write-Host "3. Restore Useful Apps" -ForegroundColor Green
  Write-Host "4. Debloat Main Profile" -ForegroundColor Green
  Write-Host "5. Work Profile" -ForegroundColor Green
  Write-Host "6. Exit"
}


# Function to execute a list of commands for a given package list
function ExecuteCommandsForPackages($packages, $command) {
  foreach ($package in $packages) {
    Write-Output "$command $package"
    adb -s $DevSID shell $command $package
  }
}

# Auto Debloat

function AutoDebloat {
  RestoreUninstalledSystemApps
  RemoveBloats
}

# Function to restore uninstalled system apps
function RestoreUninstalledSystemApps {
  foreach ($userID in $UserIDs) {
    $installedApps = (adb -s $DevSID shell pm list packages -s --user $userID) -replace '^package:', ''
    $appsToRestore = (adb -s $DevSID shell pm list packages -s -u --user $userID) -replace '^package:', '' | Where-Object { $_ -notin $installedApps } | Sort-Object -Unique
    ExecuteCommandsForPackages $appsToRestore "cmd package install-existing --user $userID"
  }
}

# Function to restore essential system apps
function RestoreEssentialSystemApps {
  foreach ($userID in $UserIDs) {
    Write-Host "Restoring System Apps for UserID: $userID" -ForegroundColor DarkMagenta
    $Usefulapps = Get-Content .\bloats\default_restore.txt
    ExecuteCommandsForPackages $Usefulapps "cmd package install-existing --user $UserID"
  }
}

# Clean Corrupt
function CleanCorrupt {
  $installedPackages = (adb -s $DevSID shell pm list packages -3 --user 0).Replace('package:', '')
  $allsystempackages = (adb -s $DevSID shell pm list packages -s -u --user 0).Replace('package:', '')
  $filteredPackages = (adb -s $DevSID shell pm list packages -u --user 0).Replace('package:', '') | Where-Object { $_ -notin $installedPackages -and $_ -notin $allsystempackages } | Sort-Object

  foreach ($package in $filteredPackages) {
    adb -s $DevSID shell pm uninstall $package
  }
}

# Function to remove bloats from Main profile
function RemoveBloats {
  foreach ($userID in $UserIDs) {
    Write-Host "Removing Bloats for UserID: $userID" -ForegroundColor DarkMagenta
    $Usefulapps = Get-Content .\bloats\default_restore.txt
    $installedApps = (adb -s $DevSID shell pm list packages -s --user $UserID) -replace '^package:', ''
    $bloatList = Get-Content -Path .\bloats\main_bloats.txt | Where-Object { $_ -match '^\S' -and $_ -notmatch '^#' -and $_ -in $installedApps -and $_ -notin $Usefulapps } | Sort-Object -Unique
    ExecuteCommandsForPackages $bloatlist "pm uninstall"
    ExecuteCommandsForPackages $bloatlist "pm uninstall --user $UserID"
    RestoreEssentialSystemApps
    CleanCorrupt
  }
}


# Work profile
function WorkProfile {
  $WUserID = ($userObjects | Where-Object { $_.UniqueID -in "1030", "10b0" }).UserID

  if (!$WUserID) { Write-Host "No Work Profile Found"; break }

  # Function to display the menu
  function Show-WorkMenu {
    Clear-Host
    Write-Host "=== Work Profile Menu ==="
    Write-Host "1. Auto Debloat Work Profile"
    Write-Host "2. Restore Uninstalled System Apps"
    Write-Host "3. Restore Essential System Apps"
    Write-Host "4. Remove All but Essential Apps"
    Write-Host "5. Exit"
  }


  # Function to restore essential system apps
  function AutoDebloatWorkProfile {
    Write-Host "Debloating Work Profile..."
    RestoreUninstalledWork
    Remove-AllButEssentialApps
    Restore-EssentialSystemApps
  }

  # Function to restore uninstalled system apps
  function RestoreUninstalledWork {
    $installedApps = (adb -s $DevSID shell pm list packages -s --user $WuserID) -replace '^package:', ''
    $appsToRestore = (adb -s $DevSID shell pm list packages -s -u --user $WuserID) -replace '^package:', '' | Where-Object { $_ -notin $installedApps } | Sort-Object -Unique
    ExecuteCommandsForPackages $appsToRestore "cmd package install-existing --user $WuserID"
  }

  # Function to restore essential system apps
  function RestoreEssentialWork {
    Write-Host "Restoring Uninstalled System Apps..."
    $workcoreApps = GetEssentialApps
    ExecuteCommandsForPackages $workcoreApps "cmd package install-existing --user $WUserID"
  }

  # Function to remove all but essential apps
  function RemoveAllButEssentialWork {
    Write-Host "Removing All but Essential Apps..."
    $workcoreApps = GetEssentialApps
    $installedWorkApps = (adb -s $DevSID shell pm list packages -s --user $WUserID) -replace '^package:', ''
    $appsToRemove = (adb -s $DevSID shell pm list packages -s --user $WUserIDs) -replace '^package:', '' | Where-Object { $_ -notin $workcoreApps -and $_ -in $installedWorkApps } | Sort-Object -Unique
    ExecuteCommandsForPackages $appsToRemove "pm uninstall --user $WUserID"
  }

  # Function to retrieve essential apps
  function GetEssentialApps {
    $esfolder = "./work_essential"
    $allpackages = (adb -s $DevSID shell pm list packages -u --user 0 | ForEach-Object { $_ -replace '^package:', '' }).Trim()

    $allmodules = Invoke-Expression "adb -s $DevSID shell pm get-moduleinfo --all"
    $moduleNames = foreach ($line in $allmodules) {
      [regex]::Match($line, 'packageName:\s*(\S+)').Groups[1].Value
    }

    $modulepkgs = $moduleNames | Where-Object { $_ -in $allpackages } | Sort-Object
    $modules_overlay = $allpackages | Where-Object { $_ -match 'overlay.modules' }

    $providers = $allpackages | Where-Object { $_ -like '*android.providers*' -and $_ -ne 'com.samsung.android.providers.factory' }

    $dual_apps_core = Get-Content -Path "$esfolder\dual_apps_core.txt"
    $others = Get-Content -Path "$esfolder\others.txt"

    $EssentialApps = $modulepkgs + $modules_overlay + $providers + $dual_apps_core + $others
    $EssentialApps = $EssentialApps | Sort-Object -Unique
    return $EssentialApps
  }

  # Loop to display the menu and process user input
  while ($true) {
    Show-WorkMenu

    $choice = Read-Host "Select an option (1-5)"

    switch ($choice) {
      1 { AutoDebloatWorkProfile }
      2 { RestoreUninstalledWork }
      3 { RestoreEssentialWork }
      4 { RemoveAllButEssentialWork }
      5 { return }
      default { Write-Host "Invalid option. Please select a valid option (1-5)." }
    }
    Pause
  }
}


# Loop to display the menu and process user input
while ($true) {
  Show-Menu

  $choice = Read-Host "Select an option (1-6)"

  switch ($choice) {
    1 { AutoDebloat }
    2 { RestoreUninstalledSystemApps }
    3 { RestoreEssentialSystemApps }
    4 { RemoveBloats }
    5 { WorkProfile }
    6 { Write-Host "Exiting..."; return }
    default { Write-Host "Invalid option. Please select a valid option (1-6)." }
  }
  Pause
}

