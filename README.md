# Scene Unpacker scripts

Language: [Русский](README_RU.md) | English

Video tour: [youtube (ru)](https://youtu.be/sWB87LuVa3s)

## What kind of repository is this

This repository contains scripts for unpacking archives in which releases are distributed, re-uploaded from [warez-scene](https://en.wikipedia.org/wiki/Warez_scene). Scripts for different operating systems using both archivers built into the OS and third-party ones.

---

Usually, when downloading archives containing material from varese scenes, there are many small archives or parts of archives and other files inside (for example, files `.nfo`, `.sfv`, `.diz`).

I don't fully understand why this is done - why compress files into an archive divided into parts, and compress all parts individually, and then put all these parts in 1 more shared archive.

Such widespread archiving and nesting of archives creates significant difficulties when manually unpacking, especially on macOS, where most archivers forcibly create a folder with the archive name and place unpacked files in it (and if there is also a folder with the same name in the root of the archive, then manual unpacking turns into hell).

As far as I know, this is because initially on the varese scenes, the material releases are distributed in the form of these small parts of 1 large archive. And those who transfer these parts to other resources simply pack them into 1 archive without first unpacking the small parts. If this is really the case, then I have a question - why initially distribute the release in the form of small parts of the archive. I have the following answers:
- the ability to download files when the Internet is unstable
- a tribute to the traditions when the Internet was slow
- difficulty analyzing the internals

All this is just a hypothesis, I have never had access to the varese scenes where the release groups initially publish their releases. If someone knows the true reasons why releases are divided into many small parts, write your version in the Issues section of this repository.

## How to use

### On Windows:
In Powershell
```powershell
cd .\Scene-Unpacker-scripts\Windows
.\Unpacker.ps1 -targetPath "path to folder with archives" -outputFolderPath "path to folder for unpacked" -overwriteExisting -smartRenameMode 1 -duplicatesProcessMode 1 -deleteArchiveAfterUnpack
```
or
```powershell
cd .\Scene-Unpacker-scripts\Windows
.\Unpacker.ps1 -targetPath "path to folder with archives"
```
or something else.

For more information about possible arguments and their description, see [documentation](./docs/docs_EN.md)

## Documentation

See in [docs folder](./docs/docs_EN.md)

## TODO

- [ ] Add an advanced logging mode for completed actions
- [ ] Add a mode to move files and folders to the Trash instead of the usual deletion
- [ ] Write/port a solution for macOS
- [ ] Write/port a solution for Linux

## System requirements

It is necessary to have the executable files of one of the archivers supported by the script in the script folder. Or the same archivers should be installed in standard folders in the system.: 

### On macOS:
- todo

### On Windows:
- 7-zip https://www.7-zip.org/
- It is also recommended to disable [Windows path length restriction](https://learn.microsoft.com/windows/win32/fileio/maximum-file-path-limitation?tabs=registry)

All code was written and tested on Windows 10 x64 22H2 with 7-Zip 24.08 (x64)

I have not checked the compatibility of the code and the Powershell functions used with previous versions. You will probably need Powershell 5.1, which comes bundled with Windows 10, to perform them.

If you are running on Windows 7, 8, 8.1, then you will probably need to install [Microsoft.NET Framework 4.8](https://support.microsoft.com/topic/microsoft-net-framework-4-8-offline-installer-for-windows-9d23f658-3b97-68ab-d013-aa3c3e7495e0 ) and [Powershell 5.1](https://www.microsoft.com/download/details.aspx/?id=54616 ) to make the code from this repository work for you.

### On Linux:
- todo