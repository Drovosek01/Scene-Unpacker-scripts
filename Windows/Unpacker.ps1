# Main script
param (
    [string]$archiverPath,
    [int]$smartRenameMode = 2,
    [switch]$deleteOriginal = $false,
    [string]$targetPath
)


# =====
# GLOBAL VARIABLES
# =====

$archiversDefaultPathes = @{
    '7z' = 'C:\Program Files\7-Zip\7z.exe';
    'bz' = 'C:\Program Files\Bandizip\bz.exe';
    'rar' = 'C:\Program Files\WinRAR\Rar.exe';
    'unrar' = 'C:\Program Files\WinRAR\UnRAR.exe'
}


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