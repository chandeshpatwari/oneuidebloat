# Work profile
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
