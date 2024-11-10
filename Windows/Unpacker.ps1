# Main script
param (
    [string]$archiverPath,
    [int]$smartRenameMode = 0,
    [switch]$deleteOriginal = $false,
    [switch]$overwriteExisting = $false,
    [Parameter(Mandatory)]
    [string]$targetPath
)

if (-not (Test-Path $targetPath)) {
    Write-Error "Archive or folder for unpack not exist"
    exit 1
}


# =====
# GLOBAL VARIABLES
# =====

$archiversDefaultPathes = @{
    '7z' = 'C:\Program Files\7-Zip\7z.exe';
    'bz' = 'C:\Program Files\Bandizip\bz.exe';
    'rar' = 'C:\Program Files\WinRAR\Rar.exe';
    'unrar' = 'C:\Program Files\WinRAR\UnRAR.exe'
}

$archiversTypes = @{
    'sevenZip' = '7z';
    'rar' = 'rar'
}

$metadataFilesExtensions = $('.nfo', '.diz', '.sfv', '.txt')

$targetFullPath = [System.IO.Path]::GetFullPath($targetPath)

# =====
# FUNCTIONS
# =====

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
Function for get and return archiver type based on archiver name

.DESCRIPTION
For different archivers need use different arguments. For example for output 
in 7z.exe need use "-o{Directory}"
but for rar.exe and unrar.exe need use "-op{Directory}"
And we will change arguments based on archiver type
#>
function GetArchiverType {
    param (
        [Parameter(Mandatory)]
        [string]$archiverPath
    )

    [string]$archiverFilename = [System.IO.Path]::GetFileName($archiverPath)
    
    if (($archiverFilename.Contains('7z')) -or ($archiverFilename.Contains('bz'))) {
        return $archiversTypes.sevenZip
    }
    
    if (($archiverFilename.ToLower()).Contains('rar')) {
        return $archiversTypes.rar
    }

    $archiversTypes.sevenZip
}

<#
.SYNOPSIS
Function for replace symbols in given text using given process mode

.DESCRIPTION
It is assumed that this renaming will be used for the main/external folders in which the release files extracted from the main/external will be located.

The function replaces dots, dashes and underscores with spaces, depending on the transmitted processing mode.
#>
function GetRenamedName {
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

function UnpackMainArchive {
    param (
        [Parameter(Mandatory)]
        [string]$archiverWorkerPath,
        [Parameter(Mandatory)]
        [string]$archivePath,
        [Parameter(Mandatory)]
        [string]$outputFolderPath,
        [Parameter(Mandatory)]
        [string]$archiverType
    )
    
    # temporary folder where the archive will be unpacked
    $unpackTempFolderPath = ''
    $archiveName = [System.IO.Path]::GetFileNameWithoutExtension($archivePath)
    
    while ($true) {
        $randomName = [System.IO.Path]::GetRandomFileName()
        $tempFolderPath = $outputFolderPath + '\' + $randomName
        
        if (-not (Test-Path $tempFolderPath)) {
            $unpackTempFolderPath = $tempFolderPath
            break
        }
    }
    
    # folder with archive name inside temp folder
    $unpackFolderPath = $unpackTempFolderPath + '\' + $archiveName
    
    [void](New-Item -Path $unpackTempFolderPath -Force -ItemType Directory)
    [void](New-Item -Path $unpackFolderPath -Force -ItemType Directory)

    if ($archiverType -eq $archiversTypes.rar) {
        [void](& $archiverWorkerPath x $archivePath -op"$unpackFolderPath")
    }

    if ($archiverType -eq $archiversTypes.sevenZip) {
        [void](& $archiverWorkerPath x $archivePath -o"$unpackFolderPath")
    }

    $itemsInUnpackedFolder = Get-ChildItem -Path $unpackFolderPath
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
            Rename-Item -Path $unpackFolderPath -NewName $tempFolderName
            Move-Item -Path ($unpackTempFolderPath + '\' + $tempFolderName + '\' + $foldersInUnpackedFolder[0].Name) -Destination $unpackTempFolderPath
            Remove-Item -Path ($unpackTempFolderPath + '\' + $tempFolderName)
            $unpackFolderPath = $unpackTempFolderPath + '\' + $foldersInUnpackedFolder[0].Name

            if ($archiveName -eq $foldersInUnpackedFolder[0].Name) {
                Write-Host "Archive and folder in archive root have same name"
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
            Move-Item -Path $foldersInUnpackedFolder[0].FullName -Destination $unpackTempFolderPath
            Remove-Item -Path $unpackFolderPath
            Rename-Item -Path $foldersInUnpackedFolder[0].FullName -NewName $archiveName
            $unpackFolderPath = $unpackTempFolderPath + '\' + $foldersInUnpackedFolder[0].FullName
            Write-Host "Archive and folder in archive root have different name"
            Write-Host "- archive name selected like base name"
        }
    }

    HandleInternalsRelease $unpackFolderPath
}

function HandleInternalsRelease {
    param (
        [Parameter(Mandatory)]
        [string]$folderPathWithItems
    )
    
    $folderItems = Get-ChildItem -Path $folderPathWithItems
    $filteredItems = $folderItems | Where-Object { 
        -not ($_.Extension -in $metadataFilesExtensions)
    }

    write-host "filteredItems $filteredItems"
    [System.Collections.Generic.List[string]]$namesFirstParts = New-Object System.Collections.Generic.List[string]

}


try {
    $archiverWorkerPath = detectArchiver $archiverPath
    # $archiverWorkerPath = 'C:\Program Files\7-Zip\7z.exe'
    $archiverType = GetArchiverType $archiverWorkerPath
    $renamedName = GetRenamedName "NCH.Software.Express.Burn.Plus.v12.02.MacOS.Incl.Keygen-BTCR" $smartRenameMode



    if (Test-Path -Path $targetFullPath -PathType Leaf) {
        Write-Host "it file"
        $parentFolder = Split-Path -Path $targetFullPath
        UnpackMainArchive $archiverWorkerPath $targetFullPath $parentFolder $archiverType
    } elseif (Test-Path -Path $targetFullPath -PathType Container) {
        # Write-Host "Это папка."
    }
    write-host "after $archiverWorkerPath"
    write-host "after $renamedName"
}
catch {
    <#Do this if a terminating exception happens#>
}