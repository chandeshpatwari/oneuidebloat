#  Start the ADB server
adb start-server

# Retrieve the list of connected devices
$devOutput = @(adb devices -l | Select-Object -Skip 1 | Select-Object -SkipLast 1)

# Function to select a device from the list
function SelectDevice {
  $index = 0
  $devOutput.ForEach({
      Write-Host "[$index]. $_"
      $index++
    })

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
  Write-Host "Allow USB Debugging, Replug USB and Re-enable USB Debugging if not getting promt. Ctrl+C to Break"
  adb reconnect offline
  adb wait-for-device
} else {
  Write-Host "Failed to connect to the device. Connect manually?"
  notepad.exe .\adb_connect.txt
  return
}

# Recheck Connection
$devOutput = @(adb devices -l | Select-Object -Skip 1 | Select-Object -SkipLast 1)
$devSelect = $devOutput[$devindex] -split '\s+'
$DevSID = $devSelect[0]
return $DevSID

function ConnectDevice {
  adb.exe wait-for-device
  $devOutput = @(adb devices -l | Select-Object -Skip 1 | Select-Object -SkipLast 1)[0]
  $selectedDevice = $devOutput -split '\s+'
  $DevSID = $selectedDevice[0]
  $devOutput
  $Confirmdevice = Read-Host "Is this the right device ? (Y/N)"
  if ($Confirmdevice -notin "Y", "y") {
    Write-Host "Disconnect all devices and reconnect the device."
  } else {
    Write-Host "Selected Device : $DevSID"
  }
}

