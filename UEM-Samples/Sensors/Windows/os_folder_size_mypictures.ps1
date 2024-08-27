# Description: Returns the total size of a folder in MB
# Return Type: INTEGER
# Execution Architecture: EITHER64OR32BIT
# Execution Context: USER
$picturesfolder = [Environment]::GetFolderPath(“MyPictures”)
$folderInfo = Get-ChildItem $picturesfolder -Recurse -File | Measure-Object -Property Length -Sum
$folderSize = ($folderInfo.Sum/1MB)
Write-output  ([System.Math]::Round($folderSize))