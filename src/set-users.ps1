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
$MultiUsers = @($userObjects | Where-Object { $_.UniqueID -notin "1030", "10b0" -and $_.Username -notin "DUAL_APP", "Secure Folder" })
$UserIDs = $MultiUsers.ForEach({ $_.UserID })
$WUserID = ($userObjects | Where-Object { $_.UniqueID -in "1030", "10b0" }).UserID
