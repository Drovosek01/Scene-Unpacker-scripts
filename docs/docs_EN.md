# Documentation

## Script arguments/parameters

1. `targetPath` | string | **required**
   - the path to the archive file to be unpacked or to the folder with the archive files
2. `archiverPath` | string | optional
   - the path to the executable file of the archiver that will process the files
   - by default, the standard path where 7-Zip is installed will be used
   - see the supported archivers in [README](../README.md ) according to the platform on which you use the script
3. `outputFolderPath` | string | optional
   - the path to the folder where the unpacked archives will be placed
   - by default, it will be unpacked to the same folder where the original archive files are located
4. `smartRenameMode` | number | optional
   - rename mode for folders with unpacked files, basically replaces dots with spaces, but not only that
   - the default number is `0` - no renaming occurs
   - for more information, see the smart renaming section below
5. `duplicatesProcessMode` | number | optional
   - analysis mode and search for duplicate files when unpacking parts of archives inside the main archive with the release
   - by default, the number is `0` - analysis for duplicate files does not occur and files with the same name are skipped when unpacking parts of archives (that is, the `-aos` argument is used in 7z)
   - for more information, see the section about duplicates below
6. `overwriteExisting` | switchable | optional
   - the presence of this parameter leads to the deletion of a folder with the same name as the "processed" unpacked folder, if there is one in the `outputFolderPath`
   - by default, the parameter is disabled, that is, if there is a folder with the same name as the final unpacked folder, then a numeric index will be added to the final unpacked folder at the end
7. `deleteArchiveAfterUnpack` | switchable | optional
   - the presence of this parameter causes the archive to be deleted after unpacking. Deleting it completely from the disk, rather than moving it to the Trash
   - by default, the option is disabled, that is, the original release archives will remain where they were originally

## Types of archives

I have not found anywhere a description of the rules according to which release groups should package their releases, but judging from my experience, this is what we may encounter:

1. All external archives have the `rar` format
   - Judging by the formats in which I downloaded files from popular varese sites, all external archives (that is, the archive files that you download, inside which there were other small archives) have the extension `.rar`
   - A friend of mine who published material on sanet told me that archives are allowed on that site only in the `.rar` format
2. The inside of the archives does not have a clear structure

If you download archives from public and popular varese sites, then most likely there will not be many small archives inside such archives, but there will be files ready for use directly. It will be enough to unpack this downloaded archive and everything is ready.

If you download archives from mirror services for scenes or from the scenes themselves, then most likely there will be many small archives inside such archives, inside which there may be both the files you need, as well as other small archives or parts of 1 large archive.

I have seen several options for such packaging of small archives.

## Possible archive structures with parts inside

The main/external archive that we download is usually 1 rar archive.

But what we need is inside and not immediately ready-made. The entire set of release files (for example, a program in exe format and a file .nfo) is compressed into a rar archive with a split parameter of a certain size. Then all these parts + the .nfo file + the file_id.diz file are packed into a regular rar archive without any separation.

Here are the options for packing small archives into 1 shared archive:

1. The release is packaged in a rar archive divided into parts with the extension `.rXX` at the end of
```
best.app.rar
├ best.app.rar
├ best.app.r00
├ best.app.r01
├ some.team.nfo
└ file_id.diz
```
And when unpacking parts of the rar archive, that is, the `.rXX` files, we will get the release files.

2. The release is packaged in a rar archive divided into parts with the extension `.partXX.rar` at the end
```
best.app.rar
├ best.app.part1.rar
├ best.app.part2.rar
├ best.app.part3.rar
├ some.team.nfo
└ file_id.diz
```
And when you unpack the parts of the rar archive, there is a file `.partXX.rar` we receive the release.

3. The same as option 1, but each part, along with the `.nfo` and `.diz` files, is packed in a zip archive.
```
best.app.rar
├ best.app-1.zip
│ ├ best.app.rar
│ ├ some.team.nfo
│ └ file_id.diz
├ best.app-2.zip
│ ├ best.app.r00
│ ├ some.team.nfo
│ └ file_id.diz
├ best.app-3.zip
│ ├ best.app.r00
│ ├ some.team.nfo
│ └ file_id.diz
├ some.team.nfo
└ file_id.diz
```
And first you need to unpack all zip archives, solving merge conflicts (that is, choosing to replace the `.nfo` and `.diz` files with those in the archive or skip the replacement), and then unpack the rar archive divided into parts

4. The same as option 2, but each part, along with the `.nfo` and `.diz` files, is packed in a zip archive.
```
best.app.rar
├ best.app-1.zip
│ ├ best.app.part1.rar
│ ├ some.team.nfo
│ └ file_id.diz
├ best.app-2.zip
│ ├ best.app.part2.rar
│ ├ some.team.nfo
│ └ file_id.diz
├ best.app-3.zip
│ ├ best.app.part3.rar
│ ├ some.team.nfo
│ └ file_id.diz
├ some.team.nfo
└ file_id.diz
```
And first you need to unpack all zip archives, solving merge conflicts (that is, choosing to replace the `.nfo` and `.diz` files with those in the archive or skip the replacement), and then unpack the rar archive divided into parts

> The difference between the parts of the rar archive in the format `.rXX` and `.partXX.rar` the problem is that the parts of `.rXX` are RAR4 format and it is considered outdated and starting with WinRAR 7, the creation of a rar archive divided into such parts is no longer supported. The format of the parts `.partXX.rar` it is considered modern and it is in this format that parts of the rar archive are created in WinRAR 7 (well, in previous versions too).

### Additional nuances with archives:

It is also worth considering that:

1. At the root of each archive, files can be located in a folder, or they can lie in a pile in the archive itself without any folder.
   - this can create a huge nesting and a huge number of folders if there are many parts
2. All this may change and be repackaged by someone, and instead of parts of rar archives, there may be parts of zip archives or 7z archives
   - parts of the zip archive can also be in both `.zXX` and `.zip.XXX` format. It is possible that parts of 7z archives may have several formats
3. When opening parts of the archive in the file manager, when clicking on any non-first part of the split archive, the archiver automatically finds the first part and begins analyzing and opening the archive from the first part. But if in CLI mode the archiver does not specify the first part for unpacking, then he will not search for the first one, but will try to unpack the specifically transferred file
   - That is, he will need to search for the first part of the archive and transfer it to the archiver himself

The essence of the script is to process all possible nuances and not waste time unpacking all the parts manually.

## Smart renaming

All the names of the archives with releases of material from the scenes that I saw do not have spaces. As a separator, there is either a dot, or a lower dash or an underscore.

For example:
```
WE.ARE.FOOTBALL.2024.Season.2024.2025-SKIDROW
Speedollama-rG
Drova_Forsaken_Kin_MacOS-DINOByTES
Safari.Pedals.Everything.Bundle.v2024.10.14.MacOS.UB.Incl.Keygen.VST-BTCR
Valentina.Server.v14.6.0.Linux.x64.RPM.Incl.Keyfilemaker-CORE
Rail.Route.Happy.Passengers.MacOS-I_KnoW
```

I do not know what principle is used to name archives and folders with releases, but dots and underscores instead of spaces between words are not always convenient. Therefore, the script also has a "smart rename" function, which will just replace dots, dashes and underscores with spaces or other characters, where necessary.

This function is enabled by adding the `-smartRenameMode` argument and passing it a digit from 0 or more. The number indicates the version of the renaming mode that will be applied.

Renaming will be used for the main/external folders where the release files extracted from the main/external will be located.

### What are the renaming modes?

- 0 - without renaming
- 1 - dots are replaced with spaces only where there are no numbers on either side of the dots. All underscores following the last dash are replaced with spaces. The last dash is replaced with spaces

For example
```
Safari.Pedals.Everything.Bundle.v2024.10.14.MacOS.UB.Incl.Keygen.VST-BTCR
>
Safari Pedals Everything Bundle v2024.10.14 MacOS UB Incl Keygen VST BTCR

Drova_Forsaken_Kin_MacOS-DINOByTES
>
Drova Forsaken Kin MacOS DINOByTES

Rail.Route.Happy.Passengers.MacOS-I_KnoW
>
Rail Route Happy Passengers MacOS I_KnoW
```

- 2 - the same as version 1, only the text after the last dash will be enclosed in square brackets

For example
```
Safari.Pedals.Everything.Bundle.v2024.10.14.MacOS.UB.Incl.Keygen.VST-BTCR
>
Safari Pedals Everything Bundle v2024.10.14 MacOS UB Incl Keygen VST [BTCR]

Drova_Forsaken_Kin_MacOS-DINOByTES
>
Drova Forsaken Kin MacOS [DINOByTES]

Rail.Route.Happy.Passengers.MacOS-I_KnoW
>
Rail Route Happy Passengers MacOS [I_KnoW]
```

- 3 - replace all dots, all dashes and all underscores with spaces in general

For example
```
Safari.Pedals.Everything.Bundle.v2024.10.14.MacOS.UB.Incl.Keygen.VST-BTCR
>
Safari Pedals Everything Bundle v2024 10 14 MacOS UB Incl Keygen VST BTCR

Drova_Forsaken_Kin_MacOS-DINOByTES
>
Drova Forsaken Kin MacOS DINOByTES

Rail.Route.Happy.Passengers.MacOS-I_KnoW
>
Rail Route Happy Passengers MacOS I KnoW
```

## Removing duplicates

Often, in the archives of the parts that are located inside the main archive with the release, the files `.nfo` and `.diz` are duplicated. That is, they all have the same name. Usually these are the same files that are in the folder with these parts of the archive, but it is not a fact that this will always be the case and perhaps some of these files are unique and have additional important information.

Parameters:
- `0` - delete duplicates
  - with this parameter, when unpacking with the 7-Zip archiver, the `-aos` argument is used, which leads to skipping unpacking the file from the archive (that is, the file is not extracted) if a file with that name is in the unpacking folder
- `1` - save duplicates
  - with this parameter, when unpacking with the 7-Zip archiver, the `-aou` argument is used, which leads to renaming the file if the file from the unpacked part is present among the unpacked files. 7-Zip adds a numeric index to the end of the name in the format `<original name>_<number from 00 and more>.<original extension>`
- next, the hash sums of all files are calculated, starting from the root of the folder into which the main release archive was unpacked
  - first, the hash sums of the files `.nfo`, `.diz`, `.txt` are calculated, which do not have a numeric index at the end of the name, since they are most likely "more original". Then the hash sums of the remaining files are calculated and compared with the hash sum of the already calculated files and the hash sum of the calculated file is the same - it is deleted
  - all files located in the root of the unpacked release folder and all subfolders are analyzed, so if you have a weak computer (processor and drive) or release files weigh a lot - this parameter will significantly increase the unpacking time

If you still don't understand how it works, try manually unpacking and exploring (10-15 pieces) the insides of different archives from varese scenes with nested archive parts and see what is inside them.

It is unlikely that the release may contain files with the same name but different contents, but this is not excluded. Therefore, if you are paranoid about this topic, the `1` parameter will help you.

## Revealed nuances

1. Do not use `rar.exe ` and `unrar.exe` for unpacking zip archives. They are designed to work only with rar archives and zip archives will be treated as self-extracting SFX archives and will not work properly with them.
   - To unpack zip archives using WinRAR, you must use WinRAR.exe in console mode, but it does not show any documentation when executing the command `WinRAR.exe --help` and throws an error when doing so.
   - Therefore, in order for the script to correctly support several archivers, it is necessary to add an archive extension check before each unpacking and if it is a zip archive, check which archiver we use and if it is `rar.exe` or `unrar.exe`, then switch to another one only for unpacking zip and 7z archives
   - Also between `7z.exe` there are other differences, for example, `-o{Directory}` is used in `7z` to specify the folder to unpack, while `-op{Directory}` is used in RAR
   - This and other incomprehensible problems when using WinRAR in console mode have led to the fact that using it in the script will add too many catch statements and reduce the readability of the code
2. The Bandizip utility `bz.exe` for some reason, it does not respond to the unpacking folder if you specify it in the format `-o{Directory}` or `-o:{Directory}`.
   - in order for the specified path to be used for unpacking, it must be written at the end of the command without any prefixes
   - this imposes additional conditions when unpacking, so I decided to withdraw support `bz.exe`
3. It is advisable to modify the target release files as little as possible. So that their creation/modification date and other attributes are not affected. It may come in handy someday.
4. Powershell automatically unpacks collections if there is 1 item in them. Therefore, when concatenating collections, a problem may arise, because an attempt to add an element to an array may occur. To prevent this, it is necessary to wrap collections in the array creation operator `@($list)` when concatenating collections