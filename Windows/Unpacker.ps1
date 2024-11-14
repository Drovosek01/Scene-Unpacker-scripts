param (
    [Parameter(Mandatory)]
    [string]$targetPath,
    [string]$archiverPath,
    [string]$outputFolderPath,
    [int]$smartRenameMode = 0,
    [int]$duplicatesProcessMode = 0,
    [switch]$overwriteExisting = $false,
    [switch]$deleteArchiveAfterUnpack = $false
)

if (-not (Test-Path $targetPath)) {
    Write-Error "Archive or folder for unpack not exist"
    exit 1
}

if ($outputFolderPath -and (-not $(Test-Path -Path $outputFolderPath))) {
    Write-Error "Output path not found"
    exit 1
} elseif ($outputFolderPath -and $(Test-Path -Path $outputFolderPath -PathType Leaf)) {
    Write-Error "Output path is file. Need folder for output unpacked data"
    exit 1
}



# =====
# GLOBAL VARIABLES
# =====

$archiversDefaultPathes = @{
    '7z' = 'C:\Program Files\7-Zip\7z.exe'
}

$metadataFilesExtensions = $('.nfo', '.diz', '.sfv', '.txt')
$archivesFilesExtensions = $('.rar', '.zip', '.7z', '.gz')
$archivesFirstPartsMatchPatterns = $('\.part0*1\.rar$', '\.zip.0*1$', '\.7z.0*1$')

$targetFullPath = [System.IO.Path]::GetFullPath($targetPath)



# =====
# FUNCTIONS
# =====

<#
.SYNOPSIS
Function for detect if supported archiver installed in system
#>
function detectDefaultArchivers {
    foreach ($key in $archiversDefaultPathes.Keys) {
        if (Test-Path $archiversDefaultPathes[$key]) {
            Write-Host "Found default archiver: $($archiversDefaultPathes[$key]) - It will be used for unpacking"
            return $archiversDefaultPathes[$key]
        }
    }
}

<#
.DESCRIPTION
Function for check does the transferred file name match the extension with the file name that is contained in one of the paths of the standard archivers
#>
function isHashTableContainGivenFilename {
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [string]$filename
    )
    
    foreach ($key in $archiversDefaultPathes.Keys) {
        $archiverFilename = [System.IO.Path]::GetFileName($archiversDefaultPathes[$key])

        if ($archiverFilename -eq $filename) {
            return $true
        }
    }

    return $false
}

<#
.SYNOPSIS
Function for determining the path to the archiver that will process the files

.DESCRIPTION
Checks whether there is a file in the file system that has been transferred as a custom archiver and whether its name matches the name of any standard archiver from the hash table.

If there is no file on the transmitted path or its name does not match the name of the standard archiver, the paths of the standard archivers will be checked and the first one that is on the disk will be used.
#>
function detectArchiver {
    [OutputType([string])]
    param (
        [string]$archiverPath
    )

    $archiverWorkerPath = ''

    $customArchiverFileName = [System.IO.Path]::GetFileName($archiverPath)


    if ($archiverPath) {
        $archiverFullPath = [System.IO.Path]::GetFullPath($archiverPath)
        
        if (Test-Path $archiverFullPath) {
            Write-Host "Found given archiver: $archiverFullPath"
            
            if (isHashTableContainGivenFilename $customArchiverFileName) {
                $archiverWorkerPath = $archiverFullPath
                Write-Host "Script support using given archiver!"
            } else {
                Write-Host "Script not support using given archiver! Will search default archivers."
                $archiverWorkerPath = detectDefaultArchivers
            }
        } else {
            Write-Host "Not found given archiver: $archiverFullPath"
            Write-Host "Will search default archivers."
            $archiverWorkerPath = detectDefaultArchivers
        }
    } else {
        $archiverWorkerPath = detectDefaultArchivers
    }
    
    if (-not $archiverWorkerPath) {
        Write-Error "Archivers not found. Install 7-zip or Bandipzip or WinRAR and relaunch script"
        exit 1
    } else {
        return $archiverWorkerPath
    }
}

<#
.SYNOPSIS
Function for replace symbols in given text using given process mode

.DESCRIPTION
It is assumed that this renaming will be used for the main/external folders in which the release files extracted from the main/external will be located.

The function replaces dots, dashes and underscores with spaces, depending on the transmitted processing mode.
#>
function GetRenamedName {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$filename,
        [Parameter(Mandatory)]
        [int]$renameMode
    )
    
    if ($renameMode -eq 0) {
        return $filename
    }
    
    if ($renameMode -eq 3) {
        return $filename.Replace('.', ' ').Replace('_', ' ').Replace('-', ' ')
    }

    $tempFilename = $filename
    $startIndex = 0
    
    if (($renameMode -eq 1) -or ($renameMode -eq 2)) {
        while ($true) {
            $dotIndex = $tempFilename.IndexOf('.', $startIndex)
    
            if ($dotIndex -eq -1) {
                break
            }
            $startIndex = $dotIndex + 1
    
            $leftSymbol = $tempFilename[$dotIndex - 1]
            $rightSymbol = $tempFilename[$dotIndex + 1]
    
            if (($leftSymbol -match '^\d$') -and ($rightSymbol -match '^\d$')) {
                continue
            } else {
                $tempFilename = $tempFilename.Substring(0, $dotIndex) + ' ' + $tempFilename.Substring($dotIndex + 1)
            }        
        }
        
        $lastDashIndex = $tempFilename.LastIndexOf('-')
    
        if ($renameMode -eq 1) {
            $tempFilename = $tempFilename.Substring(0, $lastDashIndex) + ' ' + $tempFilename.Substring($lastDashIndex + 1)
        }
    
        if ($renameMode -eq 2) {
            $tempFilename = $tempFilename.Substring(0, $lastDashIndex) + ' [' + $tempFilename.Substring($lastDashIndex + 1) + ']'
        }
    }

    return $tempFilename
}

<#
.SYNOPSIS
Function replace uniq random name for folder which can be created in the transferred folder
#>
function GetUniqRandomFolder {
    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [string]$outputFolderPath
    )
    
    while ($true) {
        $randomName = [System.IO.Path]::GetRandomFileName()
        $tempFolderPath = $outputFolderPath + '\' + $randomName
        
        if (-not (Test-Path $tempFolderPath)) {
            return $tempFolderPath
        }
    }
}

<#
.SYNOPSIS
Function for unpacking release arcvhive and process all included files
#>
function UnpackMainArchive {
    param (
        [Parameter(Mandatory)]
        [string]$archiverWorkerPath,
        [Parameter(Mandatory)]
        [string]$archivePath,
        [Parameter(Mandatory)]
        [string]$outputFolderPath
    )

    Write-Host "Start process file $archivePath"
    
    # temporary folder where the archive will be unpacked
    $unpackTempFolderPath = ''
    $archiveName = [System.IO.Path]::GetFileNameWithoutExtension($archivePath)
    
    $unpackTempFolderPath = GetUniqRandomFolder $outputFolderPath
    
    # folder with archive name inside temp folder
    $unpackFolderPath = $unpackTempFolderPath + '\' + $archiveName
    
    [void](New-Item -Path $unpackTempFolderPath -Force -ItemType Directory)
    [void](New-Item -Path $unpackFolderPath -Force -ItemType Directory)

    try {
        [void](& $archiverWorkerPath x $archivePath -o"$unpackFolderPath")
    }
    catch {
        Write-Error "Error while trying unpack Main release archive"
        Write-Error $_.Exception.Message
        exit 1
    }

    $itemsInUnpackedFolder = Get-ChildItem -LiteralPath $unpackFolderPath
    $foldersInUnpackedFolder = $itemsInUnpackedFolder | Where-Object { $_.PSIsContainer }

    if (($itemsInUnpackedFolder.Count -eq 1) -and ($foldersInUnpackedFolder.Count -eq 1)) {
        $dotsCountArchiveName = ([regex]::Matches($archiveName, '\.')).Count
        $dotsCountUnpackedFolderName = ([regex]::Matches($foldersInUnpackedFolder[0].Name, '\.')).Count

        # TODO:
        # To reduce the number of operations with the file system, we can look at the inside of the archive in advance
        # for example, using the "7z.exe l archive.rar" command and determine whether we need to create a folder
        # with the archive name before that, or such a folder already lies in the archive itself

        if (($archiveName -eq $foldersInUnpackedFolder[0].Name) -or ($dotsCountUnpackedFolderName -gt $dotsCountArchiveName)) {
            # Processing 2 naming options
            # 1. If there is another folder with the same name in the created folder, then we extract this folder outside,
            # and delete the created folder in order to save the metadata of the subfolder
            # 2. If archive has less dots than folder inside archive root
            # for exmaple in archive "FLARE-1918-MAC.rar" we have folder "Lunacy.Audio.BEAM.v1.1.6.Incl.Keygen.macOS-FLARE"
            # and folder name "Lunacy.Audio.BEAM.v1.1.6.Incl.Keygen.macOS-FLARE" has more details about release and product
            # therefore, we leave the folder with the name "Lunacy.Audio.BEAM.v1.1.6.Incl.Keygen.macOS-FLARE" as the main release folder
            $tempFolderName = "folderForDelete"
            Rename-Item -LiteralPath $unpackFolderPath -NewName $tempFolderName
            Move-Item -LiteralPath ($unpackTempFolderPath + '\' + $tempFolderName + '\' + $foldersInUnpackedFolder[0].Name) -Destination $unpackTempFolderPath
            Remove-Item -LiteralPath ($unpackTempFolderPath + '\' + $tempFolderName)
            $unpackFolderPath = $unpackTempFolderPath + '\' + $foldersInUnpackedFolder[0].Name

            if ($archiveName -eq $foldersInUnpackedFolder[0].Name) {
                Write-Host "Archive and folder in archive root have same name $archiveName"
                Write-Host "- folder from root will replace folder with archive name"
            } else {
                Write-Host "Archive and folder in archive root have different name"
                Write-Host "- folder name from root selected like base name"
            }
        } elseif ($dotsCountArchiveName -gt $dotsCountUnpackedFolderName) {
            # If archive has more dots than folder inside archive root
            # for exmaple in archive "Lunacy.Audio.BEAM.v1.1.6.Incl.Keygen.macOS-FLARE.rar" we have folder "FLARE-1918-MAC"
            # and folder name "Lunacy.Audio.BEAM.v1.1.6.Incl.Keygen.macOS-FLARE" has more details about release and product
            # therefore, we leave the folder with the name "Lunacy.Audio.BEAM.v1.1.6.Incl.Keygen.macOS-FLARE" as the main release folder
            Move-Item -LiteralPath $foldersInUnpackedFolder[0].FullName -Destination $unpackTempFolderPath
            Remove-Item -LiteralPath $unpackFolderPath
            Rename-Item -LiteralPath $foldersInUnpackedFolder[0].FullName -NewName $archiveName
            $unpackFolderPath = $unpackTempFolderPath + '\' + $foldersInUnpackedFolder[0].FullName
            Write-Host "Archive and folder in archive root have different name"
            Write-Host "- archive name selected like base name"
        }
    }

    HandleInternalsRelease $unpackFolderPath

    $finalFolderName = (Get-ChildItem -LiteralPath $unpackFolderPath).Parent.Name
    $finalFolderName = GetRenamedName $finalFolderName $smartRenameMode
    $finalFolderExistInOutputFolder = Get-ChildItem -LiteralPath $outputFolderPath -Directory | Where-Object { $_.Name -eq $finalFolderName }

    if ($overwriteExisting) {
        if ($finalFolderExistInOutputFolder) {
            Remove-Item -LiteralPath "$outputFolderPath\$finalFolderName" -Force -Recurse
        }
        Move-Item -LiteralPath $unpackFolderPath -Destination "$outputFolderPath\$finalFolderName" -Force
    } else {
        $indexSuffix = 0
        if ($finalFolderExistInOutputFolder) {
            while ($true) {
                if (Test-Path "$outputFolderPath\$finalFolderName $indexSuffix") {
                    $indexSuffix++
                } else {
                    break
                }
            }
            Move-Item -LiteralPath $unpackFolderPath -Destination "$outputFolderPath\$finalFolderName $indexSuffix"
        } else {
            Move-Item -LiteralPath $unpackFolderPath -Destination "$outputFolderPath\$finalFolderName"
        }
    }
    Remove-Item -LiteralPath $unpackTempFolderPath -Force -Recurse

    if ($deleteArchiveAfterUnpack) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    Write-Host "End process file $archivePath"
    Write-Host
}

<#
.SYNOPSIS
Function for remove duplice files

.DESCRIPTION
Function compute hash all files in recived folder and all subfolders and deletes files whose hash is repeated
#>
function RemoveDuplicateFiles {
    param (
        [Parameter(Mandatory)]
        [string]$folderPathWithItems
    )
    
    $files = Get-ChildItem -LiteralPath $folderPathWithItems -Recurse -File
    
    # force move meta-files without postfix _00, _01, _02 ... etc to start files collection
    $patterns = $metadataFilesExtensions | ForEach-Object { "_\d+\$_$" }

    $metaFilesAll = $files | Where-Object {
        $file = $_
        $metadataFilesExtensions | Where-Object { $file.Extension -in $_ }
    }
    $metaFilesNotBase = $metaFilesAll | Where-Object {
        $file = $_
        $patterns | Where-Object { $file.Name -match $_ }
    }
    $metaFilesBase = $metaFilesAll | Where-Object {
        $file = $_
        -not ($patterns | Where-Object { $file.Name -match $_ })
    }
    $metaFilesAll = $metaFilesBase + $metaFilesNotBase

    $nonMetaFiles = $files | Where-Object { 
        $file = $_
        -not ($metadataFilesExtensions | Where-Object { $file.Extension -in $_ })
    }

    $sortedFiles = $metaFilesAll + $nonMetaFiles
    $fileHashes = @{}
    $duplicatesCounter = 0

    foreach ($file in $sortedFiles) {
        try {
            $fileHash = Get-FileHash -LiteralPath $file.FullName -Algorithm MD5

            if ($fileHashes.ContainsKey($fileHash.Hash)) {
                # Write-Host "Remove duplicate: $($file.FullName)"
                $duplicatesCounter += 1
                Remove-Item -LiteralPath $file.FullName -Force
            } else {
                $fileHashes[$fileHash.Hash] = $file.FullName
            }
        }
        catch {
            Write-Host "Error while process file: $($file.FullName)"
        }
    }
    
    if ($duplicatesCounter -gt 0) {
        Write-Host "Duplicates: found $duplicatesCounter and removed"
    } else {
        Write-Host "Duplicates: not found"
    }
}

<#
.SYNOPSIS
Function for unpacking archive parts included in main/release archive
#>
function UnpackArchiveParts {
    param (
        [Parameter(Mandatory)]
        [string]$folderPathWithItems
    )
    
    $unpackTempFolderPath = GetUniqRandomFolder $folderPathWithItems

    [void](New-Item -Path $unpackTempFolderPath -Force -ItemType Directory)
    
    $files = Get-ChildItem -LiteralPath $folderPathWithItems -File
    
    $rarNewParts = $files | Where-Object { $_.Name -match '\.part\d+\.rar$' }
    $rarNewFirstParts = $rarNewParts | Where-Object { $_.Name -match '\.part0*1\.rar$' }
    
    $rarOldParts = $files | Where-Object { $_.Name -match '\.r*\d+$' }
    $rarOldFirstPartsNames = $rarOldParts | Where-Object { $_.Name -match '\.r0*1$' } | ForEach-Object { $_ -replace '\.r0*1$', '.rar' }
    $rarOldFirstParts = $files | Where-Object {
        $file = $_
        $rarOldFirstPartsNames | Where-Object {
            $file.Name -eq $_
        }
    }
    
    $zipNewFirstParts = $files | Where-Object { $_.Name -match '\.zip.0*1$' }
    
    $zipOldParts = $files | Where-Object { $_.Name -match '\.z*\d+$' }
    $zipOldFirstPartsNames = $zipOldParts | Where-Object { $_.Name -match '\.z0*1$' } | ForEach-Object { $_ -replace '\.z0*1$', '.rar' }
    $zipOldFirstParts = $files | Where-Object {
        $file = $_
        $zipOldFirstPartsNames | Where-Object {
            $file.Name -eq $_
        }
    }

    $7zFirstParts = $files | Where-Object { $_.Name -match '\.7z.0*1$' }
    
    $unpackTargets = @($rarNewFirstParts) + @($rarOldFirstParts) + @($zipNewFirstParts) + @($zipOldFirstParts) + @($7zFirstParts)
    $allArchives = @($rarNewParts) + @($rarOldParts) + @($rarOldFirstParts) + @($zipNewFirstParts) + @($zipOldParts) + @($zipOldFirstParts) + @($7zFirstParts) 
    
    foreach ($archiveFile in $unpackTargets) {
        $unpackFolderArchivePath = $unpackTempFolderPath + '\' + [System.IO.Path]::GetFileNameWithoutExtension($archiveFile.Name)
        [void](New-Item -Path $unpackFolderArchivePath -Force -ItemType Directory)

        if ($duplicatesProcessMode -eq 0) {
            try {
                [void](& $archiverWorkerPath x $archiveFile.FullName -o"$unpackFolderArchivePath" -aos)
            }
            catch {
                Write-Error "Error while trying unpack zip archives with delete duplicates"
                Write-Error $_.Exception.Message
                exit 1
            }
        } elseif ($duplicatesProcessMode -eq 1) {
            try {
                [void](& $archiverWorkerPath x $archiveFile.FullName -o"$unpackFolderArchivePath" -aou)
            }
            catch {
                Write-Error "Error while trying unpack zip archives with save duplicates"
                Write-Error $_.Exception.Message
                exit 1
            }
        }
    }

    $allArchives | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }

    $itemsInside = Get-ChildItem -LiteralPath $unpackTempFolderPath
    $foldersInside = Get-ChildItem -LiteralPath $unpackTempFolderPath -Directory

    if (($itemsInside.Count -eq $foldersInside.Count) -and ($foldersInside.Count -eq 1)) {
        $itemsInside2 = Get-ChildItem -LiteralPath $itemsInside.FullName
        $foldersInside2 = Get-ChildItem -LiteralPath $itemsInside.FullName -Directory
    
        if (($itemsInside2.Count -eq $foldersInside2.Count) -and ($foldersInside2.Count -eq 1)) {
            Move-Item -LiteralPath $foldersInside2.FullName -Destination $folderPathWithItems
        } else {
            Move-Item -Path "$($foldersInside.FullName)\*" -Destination $folderPathWithItems
        }
    } else {
        Move-Item -Path "$unpackTempFolderPath\*" -Destination $folderPathWithItems
    }
    Remove-Item -LiteralPath $unpackTempFolderPath -Force -Recurse
}

function UnpackOnlyArchiveParts {
    param (
        [Parameter(Mandatory)]
        [string]$folderPathWithItems,
        [Parameter(Mandatory)]
        [string]$outputFolderPath,
        [Parameter(Mandatory)]
        [bool]$needCreateFolderNamedArchive = $false,
        [Parameter(Mandatory)]
        [bool]$needRemoveUnpackedArchives = $false
    )
    
    $files = Get-ChildItem -LiteralPath $folderPathWithItems -File
    
    $rarNewParts = $files | Where-Object { $_.Name -match '\.part\d+\.rar$' }
    $rarNewFirstParts = $rarNewParts | Where-Object { $_.Name -match '\.part0*1\.rar$' }
    
    $rarOldParts = $files | Where-Object { $_.Name -match '\.r*\d+$' }
    $rarOldFirstPartsNames = $rarOldParts | Where-Object { $_.Name -match '\.r0*1$' } | ForEach-Object { $_ -replace '\.r0*1$', '.rar' }
    $rarOldFirstParts = $files | Where-Object {
        $file = $_
        $rarOldFirstPartsNames | Where-Object {
            $file.Name -eq $_
        }
    }
    
    $zipNewFirstParts = $files | Where-Object { $_.Name -match '\.zip.0*1$' }
    
    $zipOldParts = $files | Where-Object { $_.Name -match '\.z*\d+$' }
    $zipOldFirstPartsNames = $zipOldParts | Where-Object { $_.Name -match '\.z0*1$' } | ForEach-Object { $_ -replace '\.z0*1$', '.rar' }
    $zipOldFirstParts = $files | Where-Object {
        $file = $_
        $zipOldFirstPartsNames | Where-Object {
            $file.Name -eq $_
        }
    }

    $7zFirstParts = $files | Where-Object { $_.Name -match '\.7z.0*1$' }
    
    $unpackTargets = @($rarNewFirstParts) + @($rarOldFirstParts) + @($zipNewFirstParts) + @($zipOldFirstParts) + @($7zFirstParts)
    $allPartsArchives = @($rarNewParts) + @($rarOldParts) + @($rarOldFirstParts) + @($zipNewFirstParts) + @($zipOldParts) + @($zipOldFirstParts) + @($7zFirstParts)
    
    foreach ($archiveFile in $unpackTargets) {
        $unpackTempFolderPath = GetUniqRandomFolder $outputFolderPath
        if ($needCreateFolderNamedArchive) {
            $unpackFolderArchivePath = $unpackTempFolderPath + '\' + [System.IO.Path]::GetFileNameWithoutExtension($archiveFile.Name)
        } else {
            $unpackFolderArchivePath = $unpackTempFolderPath
        }

        [void](New-Item -Path $unpackFolderArchivePath -Force -ItemType Directory)

        if ($duplicatesProcessMode -eq 0) {
            try {
                [void](& $archiverWorkerPath x $archiveFile.FullName -o"$unpackFolderArchivePath" -aos)
            }
            catch {
                Write-Error "Error while trying unpack zip archives with delete duplicates"
                Write-Error $_.Exception.Message
                exit 1
            }
        } elseif ($duplicatesProcessMode -eq 1) {
            try {
                [void](& $archiverWorkerPath x $archiveFile.FullName -o"$unpackFolderArchivePath" -aou)
            }
            catch {
                Write-Error "Error while trying unpack zip archives with save duplicates"
                Write-Error $_.Exception.Message
                exit 1
            }
        }
        
        if ($needCreateFolderNamedArchive) {
            $unpackFolderArchivePath = $unpackTempFolderPath + '\' + [System.IO.Path]::GetFileNameWithoutExtension($archiveFile.Name)
        } else {
            $unpackFolderArchivePath = $unpackTempFolderPath
        }
    }

    if ($needRemoveUnpackedArchives) {
        $allArchives | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    }

    $itemsInsideTemp = Get-ChildItem -LiteralPath $unpackTempFolderPath
    $foldersInsideTemp = Get-ChildItem -LiteralPath $unpackTempFolderPath -Directory

    if (($itemsInside.Count -eq $foldersInsideTemp.Count) -and ($foldersInsideTemp.Count -eq 1)) {
        $itemsInside2 = Get-ChildItem -LiteralPath $itemsInsideTemp.FullName
        $foldersInside2 = Get-ChildItem -LiteralPath $itemsInsideTemp.FullName -Directory
    
        if (($itemsInside2.Count -eq $foldersInside2.Count) -and ($foldersInside2.Count -eq 1)) {
            Move-Item -LiteralPath $foldersInside2.FullName -Destination $folderPathWithItems
        } else {
            Move-Item -Path "$($foldersInsideTemp.FullName)\*" -Destination $folderPathWithItems
        }
    } else {
        Move-Item -Path "$unpackTempFolderPath\*" -Destination $folderPathWithItems
    }
    Remove-Item -LiteralPath $unpackTempFolderPath -Force -Recurse
}

<#
.SYNOPSIS
Function for process files included in main/release archive
#>
function HandleInternalsRelease {
    param (
        [Parameter(Mandatory)]
        [string]$folderPathWithItems
    )
    
    $folderItems = Get-ChildItem -LiteralPath $folderPathWithItems
    $filteredItems = $folderItems | Where-Object { 
        -not ($_.Extension -in $metadataFilesExtensions)
    }

    if ($filteredItems.Count -eq ($folderItems | Where-Object { $_.Name -match '\.zip$' }).Count) {
        Write-Host "Release archive contains only many zip-archives. Will procees all it."
        $unpackTempFolderPath = GetUniqRandomFolder $folderPathWithItems
        
        [void](New-Item -Path $unpackTempFolderPath -Force -ItemType Directory)

        if ($duplicatesProcessMode -eq 0) {
            try {
                [void](& $archiverWorkerPath x ($folderPathWithItems + '\*.zip') -o"$unpackTempFolderPath" -aos)
            }
            catch {
                Write-Error "Error while trying unpack zip archives with delete duplicates"
                Write-Error $_.Exception.Message
                exit 1
            }
        } elseif ($duplicatesProcessMode -eq 1) {
            try {
                [void](& $archiverWorkerPath x ($folderPathWithItems + '\*.zip') -o"$unpackTempFolderPath" -aou)
            }
            catch {
                Write-Error "Error while trying unpack zip archives without save duplicates"
                Write-Error $_.Exception.Message
                exit 1
            }
            RemoveDuplicateFiles $folderPathWithItems
        }
        
        # removing all main zip-files
        $zipFiles = Get-ChildItem -LiteralPath $folderPathWithItems -File -Filter "*.zip"
        $zipFiles | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }

        $itemsInUnpackTemp = Get-ChildItem -LiteralPath $unpackTempFolderPath
        $foldersInUnpackTemp = Get-ChildItem -LiteralPath $unpackTempFolderPath -Directory

        if (($foldersInUnpackTemp.Count -eq 1) -and ($itemsInUnpackTemp.Count -eq $foldersInUnpackTemp.Count)) {
            UnpackArchiveParts $folderPathWithItems
        } else {
            UnpackArchiveParts $unpackTempFolderPath
            
            $itemsInside = Get-ChildItem -LiteralPath $unpackTempFolderPath
            $foldersInside = Get-ChildItem -LiteralPath $unpackTempFolderPath -Directory
            
            if (($itemsInside.Count -eq $foldersInside.Count) -and ($foldersInside.Count -eq 1)) {
                Move-Item -LiteralPath $foldersInside[0].FullName -Destination $folderPathWithItems
            } else {
                Move-Item -Path "$unpackTempFolderPath\*" -Destination $folderPathWithItems -Force
            }
            Remove-Item -LiteralPath $unpackTempFolderPath -Force -Recurse
        }
    } else {
        Write-Host "Release archive contains NOT only many zip-archives. Will procees all it."
        UnpackArchiveParts $folderPathWithItems
    }

    # TODO:
    # Maybe here need handle cases when in  main release archive contained
    # heap only little .7z files or only little .rar files or other formats
}



# =====
# MAIN
# =====

try {
    $archiverWorkerPath = detectArchiver $archiverPath
    
    $outputFolder = Split-Path -Path $targetFullPath

    if (Test-Path -Path $targetFullPath -PathType Leaf) {
        Write-Host "Target is file"
        Write-Host
        if ($outputFolderPath -and $(Test-Path -Path $outputFolderPath -PathType Container)) {
            $outputFolder = $outputFolderPath
        }

        $targetFile = Get-ChildItem -LiteralPath $targetFullPath
        $fileIsArchive = $false

        if ($archivesFilesExtensions | Where-Object { $targetFile.Extension -in $_ }) {
            if ($targetFile.Name -match "\.part0*[2-9]") {
                Write-Error "Give first part or whole archive. Not first part cannot be used for unpack."
                exit 1
            }

            $fileIsArchive = $true
        } elseif ($archivesFirstPartsMatchPatterns | Where-Object { $targetFullPath -match $_ }) {
            $fileIsArchive = $true
        }

        if (-not $fileIsArchive) {
            Write-Error "Looks like given file is not archive or not first part of archive"
            exit 1
        }

        UnpackMainArchive $archiverWorkerPath $targetFullPath $outputFolder
    } elseif (Test-Path -Path $targetFullPath -PathType Container) {
        Write-Host "Target is folder"
        Write-Host
        $outputFolder = $targetFullPath
        if ($outputFolderPath -and $(Test-Path -Path $outputFolderPath -PathType Container)) {
            $outputFolder = $outputFolderPath
        }

        $filesInTargetFolder = Get-ChildItem -LiteralPath $targetFullPath -File
        $archivesInTargetFolder = $filesInTargetFolder | Where-Object { $_.Extension -in $archivesFilesExtensions }
        
        $archivesInTargetFolder | ForEach-Object { UnpackMainArchive $archiverWorkerPath $_.FullName $outputFolder }
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}