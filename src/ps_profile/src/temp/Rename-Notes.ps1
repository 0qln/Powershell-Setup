param(
    [Parameter(Mandatory=$true)]
    [string]$VaultPath,
    
    [string]$TestFile,
    
    [switch]$WhatIf
)

function Format-Title {
    param([string]$title)
    ($title -replace ' ', '-' -replace '[^A-Za-z0-9-]', '').ToLower()
}

function Update-ObsidianNote {
    param(
        [System.IO.FileInfo]$File,
        [string]$VaultRoot
    )

    $content = Get-Content $File.FullName -Raw
    $modified = $false
    $oldId = $null
    $aliases = @()
    $newId = $null
    $newFilename = $null

    if ($content -match '(?s)^---(.*?)---(.*)') {
        $frontMatter = $matches[1]
        $restContent = $matches[2]

        # Extract existing ID
        if ($frontMatter -match 'id:\s*(.*)') {
            $oldId = $matches[1].Trim()
        }

        # Improved alias extraction
        $aliases = @()
        $inAliases = $false
        foreach ($line in $frontMatter -split '\r?\n') {
            if ($line -match '^aliases:\s*$') {
                $inAliases = $true
                continue
            }
            if ($inAliases) {
                if ($line -match '^\s*-\s*(.*)') {
                    $aliases += $matches[1].Trim()
                }
                elseif ($line -match '^\S') {
                    $inAliases = $false
                }
            }
        }

        # Determine processing case
        if ($oldId -match '^(\d{10})-([A-Z]{4})$') {
            $timestamp = $matches[1]
            $suffix = $matches[2]
            
            if ($aliases.Count -gt 0) {
                # Case 2: Has timestamp ID and aliases
                $aliasTitle = $aliases[0]
                $formattedTitle = Format-Title -title $aliasTitle
                $newId = "$timestamp-$formattedTitle"
                $modified = $true
            }
        }
        elseif (-not [string]::IsNullOrEmpty($oldId) -and -not ($oldId -match '^\d{10}-[a-zA-Z0-9-]+$')) {
            # Case 1: Simple ID without timestamp and not in numeric format
            $timestamp = [DateTimeOffset]::Now.ToUnixTimeSeconds()
            $formattedTitle = Format-Title -title $oldId
            $newId = "$timestamp-$formattedTitle"
            $modified = $true
        }

        if ($modified) {
            # Add old ID to aliases only if it was a "readable name"
            if (-not ($oldId -match '^\d{10}-[A-Z]{4}$') -and 
                -not ($aliases -contains $oldId) -and 
                -not [string]::IsNullOrEmpty($oldId)) {
                $aliases = @($oldId) + $aliases
            }

            # Update front matter
            $newFrontMatter = $frontMatter -replace 'id:\s*.*', "id: $newId"
            
            # Update aliases section
            $aliasLines = $aliases | ForEach-Object { "  - $_" }
            $newFrontMatter = $newFrontMatter -replace '(?s)(aliases:.*?)(\r?\n\S|$)', "aliases:`n$($aliasLines -join "`n")`$2"
            
            $newContent = "---$newFrontMatter---$restContent"
            $newFilename = "$newId.md"
            
            return [PSCustomObject]@{
                OriginalPath = $File.FullName
                NewPath = Join-Path $File.DirectoryName $newFilename
                NewContent = $newContent
                ShouldRename = $true
            }
        }
    }

    return [PSCustomObject]@{
        OriginalPath = $File.FullName
        NewPath = $File.FullName
        NewContent = $null
        ShouldRename = $false
    }
}

# Main execution
if ($TestFile) {
    if (-not (Test-Path $TestFile)) {
        Write-Error "Test file not found: $TestFile"
        exit 1
    }
    
    $file = Get-Item $TestFile
    $result = Update-ObsidianNote -File $file -VaultRoot $VaultPath
    
    if ($result.ShouldRename) {
        Write-Host "`nTEST RUN RESULTS:"
        Write-Host "Original path: $($result.OriginalPath)"
        Write-Host "Would rename to: $($result.NewPath)"
        Write-Host "`nFirst 3 lines of new content:"
        $result.NewContent.Split("`n")[0..2] | ForEach-Object { Write-Host "  $_" }
        
        if (-not $WhatIf) {
            $choice = Read-Host "`nApply changes? (y/n)"
            if ($choice -eq 'y') {
                $result.NewContent | Out-File $result.NewPath -Encoding utf8
                Remove-Item $result.OriginalPath
                Write-Host "Changes applied!"
            }
            else {
                Write-Host "No changes made"
            }
        }
    }
    else {
        Write-Host "File does not need modification: $TestFile"
    }
}
else {
    $files = Get-ChildItem -Path $VaultPath -Filter *.md -Recurse
    $processed = 0

    foreach ($file in $files) {
        $result = Update-ObsidianNote -File $file -VaultRoot $VaultPath
        
        if ($result.ShouldRename) {
            Write-Host "Renaming $($file.Name) to $([System.IO.Path]::GetFileName($result.NewPath))"
            
            if (-not $WhatIf) {
                $result.NewContent | Out-File $result.NewPath -Encoding utf8
                Remove-Item $result.OriginalPath
                $processed++
            }
        }
    }

    if ($WhatIf) {
        Write-Host "WhatIf: Would have processed $processed files"
    }
    else {
        Write-Host "Processed $processed files"
    }
}
