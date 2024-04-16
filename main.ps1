# Connect Device
function connectdevice {
  adb start-server
  function listdevices {
    $availabledevices = @(adb devices -l | Select-Object -Skip 1 | Select-Object -SkipLast 1)
    return $availabledevices
  }

  if ($availabledevices.Count -eq 0) { return } 
  else {
    for ($i = 0; $i -lt $availabledevices.Count; $i++) { Write-Host "[$i]. $devOutput[$i]" }
    $devindex = Read-Host 'Select a device.'
    while ($devindex -gt ($availabledevices.Count - 1)) { $devindex = Read-Host 'Try again.' }
  }

  $selecteddevice = $availabledevices[$devindex]

  if ($selecteddevice.Contains('device')) {
    Write-Host 'Device connected' -ForegroundColor Green
  } elseif ($selecteddevice.Contains('unauthorized')) {
    Write-Host 'Allow usb debugging/replug the cable and re-enable usb debugging.'
    adb reconnect offline; adb wait-for-device
  } else { Read-Host 'Failed to connect. Connect manually then restart the script'; return }
  
  if (listdevices) { $selecteddevice = ((listdevices).Split())[$devindex] } else {
    Read-Host 'Failed to connect. Connect manually then restart the script'; return
  }

  return $selecteddevice
}


function Get-Users {
  $usersOutput = adb -s $selecteddevice shell pm list users -like '*UserInfo*'
  $usersOutput = [Regex]::Matches($usersOutput, '\{(.*?)\}') -replace '[{}]', ''   
  $userObjects = foreach ($users in $usersOutput) {
    $PropArray = $users.split(':')
    [PSCustomObject]@{ UserID = $PropArray[0]; Username = $PropArray[1]; UniqueID = $PropArray[2] }
  }  
  return $userObjects
}


# Applications that are neither user-installed nor pre-installed as system apps.
function ClearRemnants {
  $installedPackages = (adb -s $selecteddevice shell pm list packages -3 --user 0).Replace('package:', '')
  $allsystempackages = (adb -s $selecteddevice shell pm list packages -s -u --user 0).Replace('package:', '')
  $packages = (adb -s $selecteddevice shell pm list packages -u --user 0).Replace('package:', '') | Where-Object { $_ -notin $installedPackages -and $_ -notin $allsystempackages } | Sort-Object
  foreach ($package in $packages) {
    Write-Host 'Removing' $package -ForegroundColor Green
    adb -s $selecteddevice shell cmd package uninstall $package
  }
}

# Function to restore uninstalled system apps
function RestoreSystemApps {
  foreach ($userID in $UserIDs) {
    $systemspps = (adb -s $selecteddevice shell pm list packages -s --user $userID).Replace('package:', '')
    $uninstalledsystemspps = (adb -s $selecteddevice shell pm list packages -s -u --user $userID).Replace('package:', '') | Where-Object { $_ -notin $systemspps }
    foreach ($package in $uninstalledsystemspps) {
      adb -s $selecteddevice shell cmd package install-existing --user $userID $package
    } 
  }
}

# Function to Remove Bloats
function RemoveBloats {
  foreach ($userID in $UserIDs) {
    $systemspps = (adb -s $selecteddevice shell pm list packages -s --user $userID).Replace('package:', '')
    $installedbloats = $systemspps | Where-Object { $_ -in $allbloats.package -and $_ -notin $usefulbloats.package } | Sort-Object -Unique
    foreach ($package in $installedbloats) {
      Write-Host 'Removing' $package -ForegroundColor Green
      adb -s $selecteddevice shell cmd package uninstall --user $UserID $package
    }
  }
  Pause
}

# Connect to a device
$selecteddevice = connectdevice
if (!$selecteddevice) { Read-Host 'No Device Found'; return }

# Retrieve User IDs.
$UserIDS = (Get-Users | Where-Object { $_.Username -NotIn @('DUAL_APP', 'Secure Folder') }).UserID
if (!$UserIDs) { Write-Host 'No Profile Found'; return }

# Fetch Files
# $allbloats = (Get-ChildItem ./pkgs).foreach({ Get-Content $_.FullName | ConvertFrom-Csv }) | Sort-Object -Property 'Action'
$allbloats = if (Test-Path './bloats.csv') { Get-Content './bloats.csv' | ConvertFrom-Csv | Sort-Object -Property 'Action' } 
else { Invoke-RestMethod 'https://github.com/chandeshpatwari/oneuidebloat/raw/main/bloats.csv' | ConvertFrom-Csv | Sort-Object -Property 'Action' } 
$knoxbloats = $allbloats | Where-Object { $_.Suite -eq 'Knox & Enterprise' }
$usefulbloats = $allbloats | Where-Object { $_.Action -eq '0' }
$purebloats = $allbloats | Where-Object { $_.Action -eq '1' }
$secondarybloats = $allbloats | Where-Object { $_.Action -eq '2' }

do {
  Clear-Host
  Write-Host '== Debloater =='
  Write-Host '1. Debloat' -ForegroundColor Green
  Write-Host '2. Restore' -ForegroundColor Green
  Write-Host '3. Restore Knox' -ForegroundColor Green
  Write-Host '4. Exit' 

  $choice = Read-Host 'Enter your choice (1-4)'
  switch ($choice) {
    1 { RemoveBloats; ClearRemnants }
    2 { RestoreSystemApps; ClearRemnants }
    3 {}
    4 { return }
    default {
      Read-Host 'Invalid choice. Press Enter to try again.'
    }
  }
} while ($choice -ne '3')
