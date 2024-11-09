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
                break
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


try {
    $archiverWorkerPath = detectArchiver $archiverPath
    $renamedName = GetRenamedName "NCH.Software.Express.Burn.Plus.v12.02.MacOS.Incl.Keygen-BTCR" $smartRenameMode
    write-host "after $archiverWorkerPath"
    write-host "after $renamedName"
}
catch {
    <#Do this if a terminating exception happens#>
}