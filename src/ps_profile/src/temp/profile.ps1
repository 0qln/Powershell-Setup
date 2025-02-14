function Activate-Script {
    param(
        [string] $Path
    )

    # Check if the file exists before adding the type
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        # Use the -LiteralPath parameter to safely handle file paths
        Add-Type -LiteralPath $Path
    }
    else {
        Write-Host "Script file not found at: $Path" -ForegroundColor Red
    }
}

$setuplocation = (get-item $PSScriptRoot).parent.FullName
$constlocation = $setuplocation + "/constants/constants.ps1"
.$constlocation

function internet-test {
    irm asheroto.com/speedtest | iex
}

function cc-bench {
    param(
        [string] $engine1,
        [string] $engine2,
        [string] $openings,
        [string] $out
    )

    &$cute_chess\"cutechess-cli.exe" `
        -engine cmd=$engine1 `
        -engine cmd=$engine2 `
        -each proto=uci tc=40/40 `
        -rounds 500 `
        -concurrency 4 `
        -openings $openings `
        -pgnout $out
}

function jar-run {
    param(
        [string] $project_folder,
        [string] $main_class
    )

    Set-Location $project_folder

    Write-Host "Packages found: "
    $packages = Get-ChildItem -Path "$project_folder\packages" -Recurse -Name | ForEach-Object { "packages\$_" }
    foreach ($package in $packages) {
        Write-Host $package
    }

    Write-Host "Compilation (1/2)"
    $items = Get-ChildItem -Directory -Path $project_folder -Exclude packages , .vscode | ForEach-Object { $_.FullName + ("\*.java") } 
    foreach ($item in $items) {
        Write-Host $item
        javac -cp ".;$($packages -join ';')" $item
    }

    Write-Host "Creating manifest"
    new-item "manifest.txt" -force > $null
    set-content -path "manifest.txt" -value "Main-Class: $main_class`r`n"

    Write-Host "Compilation (2/2)"
    Invoke-Expression "jar --create --file out.jar --manifest manifest.txt -C $project_folder ." 

    Write-Host "Starting program"
    java -cp ".;$($packages -join ';')" -jar out.jar
}

function java-run {
    param(
        [string] $project_folder,
        [string] $main_class
    )

    Write-Host "Packages found: "
    $packages = Get-ChildItem -Path "$project_folder\packages" -Recurse -Name | ForEach-Object { "packages\$_" }
    foreach ($package in $packages) {
        Write-Host $package
    }

    Set-Location $project_folder

    Write-Host "Start compilation"
    $items = Get-ChildItem -Directory -Path $project_folder -Exclude packages , .vscode | ForEach-Object { $_.FullName + ("\*.java") } 
    foreach ($item in $items) {
        Write-Host $item
        javac -cp ".;$($packages -join ';')" $item
    }

    Write-Host "Start program"
    java -cp ".;$($packages -join ';')" $main_class
}



# fzf wrappers
function fzx {
    Get-ChildItem . -Recurse 
    | Invoke-Fzf 
    | % { iex $_ }
}

function cdf {
    Get-ChildItem . -Recurse | Invoke-Fzf | Set-Location
}

function cdfnr { # cd, no recurse
    Get-ChildItem . | Invoke-Fzf | Set-Location
}

function nvimf {
    Get-ChildItem . -Recurse | Invoke-Fzf | % { nvim $_ }
}

function echof {
    Get-ChildItem . -Recurse | Invoke-Fzf | echo 
}


# explorer shortcut
    # opens any path in explorer
function expl {
    param(
        [string] $path
    )
    explorer.exe $path }


# Open specific weevil version
function Open-Weevil {
	param(
		[string] $version
	)
	cd "$WEEVIL_DIR\music_cache\"
	py "$WEEVIL_DIR\$version/src/__main__.py" 
}



# Open latest weevil version
function Weevil {	
	$versions = Get-ChildItem -Path $WEEVIL_DIR -Directory -Exclude "music_cache", "src"
	
	if ($versions.Count -eq 0) {
		Write-Host "No version folders found in '$WEEVIL_DIR'"
		return
	}

	$latestVersion = 
		$versions | 
		Sort-Object { [System.Version]::new($_.name) } | 
		Select-Object -Last 1

	Write-Host "Start Weevil"$latestVersion.name

	Open-Weevil $latestVersion.name
}


# Create new weevil version from current dev setup
function Update-Weevil {
    param(
        # major, minor, build, revision
        [string] $part = "minor"
    )

    $versions = Get-ChildItem -Path $WEEVIL_DIR -Directory -Exclude "music_cache", "src"
	
    $newVersion = 
        If ($versions.Count -eq 0) { 
            [System.Version]::new("1.0.0.0") 
        }
        Else { 
            Increase-Version -Version ($versions | Sort-Object { [System.Version]::new($_.name) } | Select-Object -Last 1).name -Part $part 
        }
        
    Write-Host "New version:" $newVersion 

    function Do-Copy {
        param(
            [string] $File
        )
        return $File -like "*.py" ` -or $File -like "*.txt"
    }

    Copy-Files -SourceFolder $WEEVIL_SRC -DestinationFolder "$WEEVIL_DIR\$newVersion\src\" -Predicate { Do-Copy -$File $_ }
}


function Increase-Version {
    param(
        [string]$Version,
        [string]$Part,
        [int]$Amount = 1
    )

    # Parse the version string
    $VersionObject = [System.Version]::new($Version)

    # Switch statement to determine which part to increase
    switch ($Part.ToLower()) {
        "major" {
            $VersionObject = [System.Version]::new($VersionObject.Major + $Amount, $VersionObject.Minor, $VersionObject.Build, $VersionObject.Revision)
        }
        "minor" {
            $VersionObject = [System.Version]::new($VersionObject.Major, $VersionObject.Minor + $Amount, $VersionObject.Build, $VersionObject.Revision)
        }
        "build" {
            $VersionObject = [System.Version]::new($VersionObject.Major, $VersionObject.Minor, $VersionObject.Build + $Amount, $VersionObject.Revision)
        }
        "revision" {
            $VersionObject = [System.Version]::new($VersionObject.Major, $VersionObject.Minor, $VersionObject.Build, $VersionObject.Revision + $Amount)
        }
        default {
            Write-Host "Invalid part specified. Please specify one of: major, minor, build, revision"
            return
        }
    }

    # Output the increased version
    Write-Output $VersionObject.ToString()
}

function Copy-Files {
    param(
        [string]$SourceFolder,
        [string]$DestinationFolder,
        [scriptblock]$Predicate
    )

    # Check if source folder exists
    if (-not (Test-Path $SourceFolder -PathType Container)) {
        Write-Host "Source folder '$SourceFolder' does not exist."
        return
    }

    # Check if destination folder exists, if not, create it
    if (-not (Test-Path $DestinationFolder -PathType Container)) {
        New-Item -ItemType Directory -Force -Path $DestinationFolder
    }

    # Get all files in the source folder
    $Files = Get-ChildItem -Path $SourceFolder -File

    # Copy each file to the destination folder based on the predicate
    foreach ($File in $Files) {
        if (& $Predicate $File) {
            $DestinationPath = Join-Path -Path $DestinationFolder -ChildPath $File.Name
            Copy-Item -Path $File.FullName -Destination $DestinationPath -Force
            Write-Host "Copied $($File.Name) to $($DestinationPath)"
        }
    }

    Write-Host "Files copied successfully from '$SourceFolder' to '$DestinationFolder'."
}


# Windows-path to URI format
function uri {
    param(
        [string] $path
    )

    Write-Host "`"$($path -replace '\\','/')`""
}
