$host.ui.rawui.BackgroundColor = "Black"
$host.ui.rawui.ForegroundColor = "White"

# Check ADB
if (!(adb.exe)) { "adb not installed"; return }

## Connect Device
. .\connect-device.ps1

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
    $Usefulapps = Get-Content .\bloats\useful-setting-apps.txt
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
    $Usefulapps = Get-Content .\bloats\useful-setting-apps.txt
    $installedApps = (adb -s $DevSID shell pm list packages -s --user $UserID) -replace '^package:', ''
    $bloatList = Get-Content -Path .\bloats\main_bloats.txt | Where-Object { $_ -match '^\S' -and $_ -notmatch '^#' -and $_ -in $installedApps -and $_ -notin $Usefulapps } | Sort-Object -Unique
    ExecuteCommandsForPackages $bloatlist "pm uninstall"
    ExecuteCommandsForPackages $bloatlist "pm uninstall --user $UserID"
    RestoreEssentialSystemApps
    CleanCorrupt
  }
}

function WorkProfile {
  .\debloat-work-profile.ps1
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
