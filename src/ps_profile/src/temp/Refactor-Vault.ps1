param(
    [Parameter(Mandatory=$true)]
    [string]$VaultPath,
    
    [string]$TargetFolder = $VaultPath,
    
    [string]$TestFile
)

function Process-ObsidianFile {
    param(
        [System.IO.FileInfo]$File,
        [string]$VaultRoot,
        [string]$TargetFolder
    )

    # Get relative path components (excluding filename)
    $relativePath = [System.IO.Path]::GetRelativePath($VaultRoot, $File.DirectoryName)
    $pathComponents = $relativePath.Split([System.IO.Path]::DirectorySeparatorChar) | 
                      Where-Object { $_ -ne '.' }

    # Read and parse file content
    $content = Get-Content $File.FullName -Raw
    
    if ($content -match '(?s)^---(.*?)---(.*)') {
        $frontMatter = $matches[1]
        $restContent = $matches[2]
        
        # Add tags to front matter
        $newTags = $pathComponents | ForEach-Object { "  - $_" }
        $updatedFrontMatter = $frontMatter -replace '(?s)tags:\s*(\[.*?\]|.*?)(\r?\n)', "tags:`n$($newTags -join "`n")`n"
        
        # Handle case where tags section didn't exist
        if (-not ($frontMatter -match 'tags:')) {
            $updatedFrontMatter = "tags:`n$($newTags -join "`n")`n" + $frontMatter
        }
        
        $newContent = "---$updatedFrontMatter---$restContent"
    }
    else {
        # Create new front matter if none existed
        $newTags = $pathComponents | ForEach-Object { "  - $_" }
        $newContent = "---`ntags:`n$($newTags -join "`n")`n---`n$content"
    }

    # Create target filename
    $targetPath = Join-Path $TargetFolder $File.Name
    
    # Handle filename conflicts
    $count = 1
    while (Test-Path $targetPath) {
        $targetPath = Join-Path $TargetFolder "$($File.BaseName)-$count$($File.Extension)"
        $count++
    }

    # Return object with changes without committing them
    return [PSCustomObject]@{
        OriginalPath = $File.FullName
        NewPath = $targetPath
        NewContent = $newContent
        TagsAdded = $pathComponents
    }
}

# Main execution
if ($TestFile) {
    if (-not (Test-Path $TestFile)) {
        Write-Error "Test file not found: $TestFile"
        exit 1
    }
    
    $file = Get-Item $TestFile
    $result = Process-ObsidianFile -File $file -VaultRoot $VaultPath -TargetFolder $TargetFolder
    
    # Display changes without applying them
    Write-Host "`nTEST RUN RESULTS:"
    Write-Host "Original path: $($result.OriginalPath)"
    Write-Host "Would move to: $($result.NewPath)"
    Write-Host "Tags to add: $($result.TagsAdded -join ', ')"
    Write-Host "`nFirst 3 lines of new content:"
    $result.NewContent.Split("`n")[0..2] | ForEach-Object { Write-Host "  $_" }
    
    # Prompt for actual execution
    $choice = Read-Host "`nApply changes for this file? (y/n)"
    if ($choice -eq 'y') {
        $result.NewContent | Out-File $result.NewPath -Encoding utf8
        Remove-Item $result.OriginalPath
        Write-Host "Changes applied!"
    }
    else {
        Write-Host "No changes made"
    }
}
else {
    # Process all files
    $files = Get-ChildItem -Path $VaultPath -Filter *.md -Recurse | Where-Object {
        $_.DirectoryName -ne $TargetFolder
    }

    foreach ($file in $files) {
        $result = Process-ObsidianFile -File $file -VaultRoot $VaultPath -TargetFolder $TargetFolder
        $result.NewContent | Out-File $result.NewPath -Encoding utf8
        Remove-Item $result.OriginalPath
    }
    Write-Host "Processed $($files.Count) files"
}
