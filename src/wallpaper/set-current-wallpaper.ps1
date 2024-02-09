# Note: if scheduling this script, you may need to check 
# that the powershell session is logged in as the user

$path = $args[0]
Add-Type -Path "Wallpaper.cs"

[Wallpaper]::SetWallpaper($path)