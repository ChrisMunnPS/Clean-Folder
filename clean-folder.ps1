<#PSScriptInfo

.VERSION 2.3.1

.GUID 6bfc8b39-87a0-442a-975f-81008dd683ca

.AUTHOR Chris

.TAGS cleanup downloads wpf gui recycle-bin

.RELEASENOTES
See CHANGELOG.md. 2.3.1: temp clean-up now removes subfolders reliably (read-only folders and junctions).

#>

#Requires -Version 5.1

<#
.SYNOPSIS
    Cleans up files by type from a folder (default: Downloads) using a WPF GUI or the command line.

.DESCRIPTION
    Run with no parameters to open the GUI: pick file types by category, scan (preview), review the
    list, then move the files to the Recycle Bin (default) or delete them permanently.

    Run with any of -Folder, -Category, -Extension, -Recurse, -Permanent, -EverQuestLogs, -NoGui or
    -WhatIf to run headless. The command line uses the same engine as the GUI and supports
    -WhatIf and -Confirm. Files go to the Recycle Bin unless -Permanent is given.

    Note: Windows may delete permanently (not recycle) on network shares, removable drives, or when a
    file is larger than the Recycle Bin allows.

    GUI settings (theme, folder, options, ticked types) are saved to %APPDATA%\CleanFolder\settings.json.
    Each run that deletes something appends a line to clean-up.log in the cleaned folder.

.PARAMETER Folder
    Folder to clean. Defaults to the current user's Downloads folder
    (or C:\everquest\logs when -EverQuestLogs is used without -Folder).

.PARAMETER Category
    One or more categories: Office, Text, Web, Images, Media, Installers, Archives, Torrents, Ebooks, Code, Temp.

.PARAMETER Extension
    Extra extensions to include, for example: pdf, rtf, sqlite (with or without a leading dot).

.PARAMETER Recurse
    Include subfolders. Reparse points (junctions/symlinks) are not followed.

.PARAMETER Permanent
    Delete permanently instead of moving files to the Recycle Bin.

.PARAMETER EverQuestLogs
    Shortcut for -Extension txt,log. Uses C:\everquest\logs unless -Folder is also supplied.

.PARAMETER NoGui
    Force headless mode.

.PARAMETER Version
    Prints the script version and exits.

.PARAMETER CleanUserTemp
    Permanently deletes everything in the current user's temp folder that is not in use, including the
    contents of all subfolders, then removes the subfolders themselves. Files in use are skipped and
    keep their folders.

.PARAMETER CleanWindowsTemp
    Same as -CleanUserTemp for C:\Windows\Temp. Requires an elevated (Run as administrator) session.

.PARAMETER EmptyRecycleBin
    Permanently empties the Recycle Bin (all drives) for the current user.

.EXAMPLE
    .\Clean-Folder.ps1
    Opens the GUI.

.EXAMPLE
    .\Clean-Folder.ps1 -Category Office,Images -Recurse -WhatIf
    Shows what would be recycled from Downloads and its subfolders.

.EXAMPLE
    .\Clean-Folder.ps1 -Folder D:\Temp -Extension pdf,mp3 -Permanent -Confirm:$false
    Permanently deletes PDFs and MP3s from D:\Temp without prompting.

.EXAMPLE
    .\Clean-Folder.ps1 -EverQuestLogs -Verbose
    Recycles .txt and .log files from C:\everquest\logs.

.EXAMPLE
    .\Clean-Folder.ps1 -CleanUserTemp -EmptyRecycleBin -WhatIf
    Shows what the user temp clean-up and Recycle Bin emptying would do, without deleting anything.

.EXAMPLE
    .\Clean-Folder.ps1 -CleanWindowsTemp
    Cleans C:\Windows\Temp (run from an elevated PowerShell session).
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Folder,

    [ValidateSet('Office', 'Text', 'Web', 'Images', 'Media', 'Installers', 'Archives', 'Torrents', 'Ebooks', 'Code', 'Temp')]
    [string[]]$Category,

    [string[]]$Extension,

    [switch]$Recurse,

    [switch]$Permanent,

    [switch]$EverQuestLogs,

    [switch]$NoGui,

    [switch]$Version,

    [switch]$CleanUserTemp,

    [switch]$CleanWindowsTemp,

    [switch]$EmptyRecycleBin
)

# Semantic Versioning 2.0.0. Keep in sync with .VERSION above and CHANGELOG.md on every change.
$ScriptVersion = '2.3.1'

# ------------------------------------------------------------------------------------------------
# Catalog of file types (Icon values are Unicode code points, keeping this file pure ASCII)
# ------------------------------------------------------------------------------------------------
$Catalog = @(
    [pscustomobject]@{ Key = 'Office';     Title = 'Office & Documents'; Icon = 0x1F4C4; Extensions = @('docx', 'doc', 'xlsx', 'xls', 'pptx', 'ppt', 'odt', 'rtf', 'one', 'vsdx', 'pdf') }
    [pscustomobject]@{ Key = 'Text';       Title = 'Text & Logs';        Icon = 0x1F4DD; Extensions = @('txt', 'log', 'md', 'csv', 'json', 'xml') }
    [pscustomobject]@{ Key = 'Web';        Title = 'Web';                Icon = 0x1F310; Extensions = @('html', 'htm', 'css', 'js', 'php') }
    [pscustomobject]@{ Key = 'Images';     Title = 'Images';             Icon = 0x1F5BC; Extensions = @('jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp') }
    [pscustomobject]@{ Key = 'Media';      Title = 'Audio & Video';      Icon = 0x1F3B5; Extensions = @('mp3', 'flac', 'wav', 'm4a', 'wma', 'mp4') }
    [pscustomobject]@{ Key = 'Installers'; Title = 'Installers & Packages'; Icon = 0x1F4E6; Extensions = @('exe', 'msi', 'msix', 'msixbundle', 'appx', 'appxbundle', 'msp', 'cab', 'pkg', 'deb', 'spk', 'bin', 'iso') }
    [pscustomobject]@{ Key = 'Archives';   Title = 'Archives';           Icon = 0x1F5C3; Extensions = @('zip', '7z', 'rar') }
    [pscustomobject]@{ Key = 'Torrents';   Title = 'Torrents & Usenet';  Icon = 0x1F4E5; Extensions = @('torrent', 'nzb') }
    [pscustomobject]@{ Key = 'Ebooks';     Title = 'eBooks';             Icon = 0x1F4DA; Extensions = @('epub', 'mobi') }
    [pscustomobject]@{ Key = 'Code';       Title = 'Code & Misc';        Icon = 0x1F4BB; Extensions = @('ps1', 'cs', 'evtx', 'eml', 'msg', 'ics') }
    [pscustomobject]@{ Key = 'Temp';       Title = 'Temp & Partial Downloads'; Icon = 0x1F5D1; Extensions = @('tmp', 'temp', 'crdownload', 'part', 'partial', 'download', 'opdownload', 'bak', 'old') }
)

$LogFileName = 'clean-up.log'

# ------------------------------------------------------------------------------------------------
# Engine functions (these are also loaded into the GUI's background runspace)
# ------------------------------------------------------------------------------------------------
function Find-CleanupFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Folder,
        [string[]]$Extensions = @(),
        [bool]$Recurse,
        [string[]]$Exclude = @(),
        [bool]$AllFiles,
        $Sync
    )

    $extSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($e in $Extensions) { [void]$extSet.Add($e) }
    $excludeSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($x in $Exclude) { if ($x) { [void]$excludeSet.Add($x) } }

    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($Folder)

    while ($pending.Count -gt 0) {
        if ($Sync -and $Sync.Cancel) { return }
        $dir = $pending.Pop()
        try {
            $dirInfo = [System.IO.DirectoryInfo]::new($dir)
            foreach ($file in $dirInfo.EnumerateFiles()) {
                if ($Sync -and $Sync.Cancel) { return }
                $ext = $file.Extension.TrimStart('.')
                if (($AllFiles -or ($ext -and $extSet.Contains($ext))) -and -not $excludeSet.Contains($file.FullName)) {
                    $file
                }
            }
            if ($Recurse) {
                foreach ($sub in $dirInfo.EnumerateDirectories()) {
                    # Do not follow junctions/symlinks (avoids loops and escaping the chosen folder)
                    if (-not ($sub.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
                        $pending.Push($sub.FullName)
                    }
                }
            }
        }
        catch {
            Write-Verbose "Skipped '$dir': $($_.Exception.Message)"
        }
    }
}

function Remove-CleanupFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [bool]$Permanent
    )

    if ($Permanent) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    }
    else {
        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
            $Path,
            [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
            [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
    }
}

function Invoke-CleanupDeletion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.IO.FileInfo[]]$Files,
        [bool]$Permanent,
        [string]$PruneRoot = '',
        $Sync
    )

    if (-not $Permanent) { Add-Type -AssemblyName Microsoft.VisualBasic }

    $result = [pscustomobject]@{
        Deleted      = 0
        Bytes        = [long]0
        Cancelled    = $false
        Failed       = [System.Collections.Generic.List[string]]::new()
        DeletedPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        ByExtension  = @{}
        PrunedDirectories = 0
        KeptDirectories = 0
    }

    if ($Sync) { $Sync.Total = $Files.Count }
    $done = 0

    foreach ($file in $Files) {
        if ($Sync -and $Sync.Cancel) { $result.Cancelled = $true; break }

        $length = [long]$file.Length
        $ext = $file.Extension.TrimStart('.').ToLowerInvariant()
        try {
            Remove-CleanupFile -Path $file.FullName -Permanent $Permanent
            $result.Deleted++
            $result.Bytes += $length
            [void]$result.DeletedPaths.Add($file.FullName)
            if (-not $result.ByExtension.ContainsKey($ext)) {
                $result.ByExtension[$ext] = [pscustomobject]@{ Count = 0; Bytes = [long]0 }
            }
            $result.ByExtension[$ext].Count++
            $result.ByExtension[$ext].Bytes += $length
        }
        catch {
            $result.Failed.Add(('{0} ({1})' -f $file.FullName, $_.Exception.Message))
        }

        $done++
        if ($Sync) { $Sync.Done = $done; $Sync.Current = $file.FullName }
    }

    # Optionally remove subfolders left empty (used for temp clean-up)
    if ($PruneRoot -and -not $result.Cancelled) {
        $pruned = Remove-EmptyDirectory -Root $PruneRoot
        $result.PrunedDirectories = [int]$pruned.Removed
        $result.KeptDirectories = [int]$pruned.Kept
    }

    $result
}

function Remove-EmptyDirectory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Root)

    $dirs = [System.Collections.Generic.List[string]]::new()
    $links = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        $current = $stack.Pop()
        try {
            foreach ($sub in [System.IO.DirectoryInfo]::new($current).EnumerateDirectories()) {
                $dirs.Add($sub.FullName)
                if ($sub.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                    # Junction or symlink: remove the link itself, never follow it or touch its target
                    [void]$links.Add($sub.FullName)
                }
                else {
                    $stack.Push($sub.FullName)
                }
            }
        }
        catch { Write-Verbose "Skipped '$current': $($_.Exception.Message)" }
    }

    $removed = 0
    # Longest paths first, so children are removed before their parents
    foreach ($dir in ($dirs | Sort-Object -Property Length -Descending)) {
        try {
            if (-not $links.Contains($dir) -and @([System.IO.Directory]::GetFileSystemEntries($dir)).Count -gt 0) { continue }

            # A read-only folder cannot be deleted until the attribute is cleared
            $attributes = [System.IO.File]::GetAttributes($dir)
            if ($attributes -band [System.IO.FileAttributes]::ReadOnly) {
                [System.IO.File]::SetAttributes($dir, ($attributes -bxor [System.IO.FileAttributes]::ReadOnly))
            }
            [System.IO.Directory]::Delete($dir)
            $removed++
        }
        catch { Write-Verbose "Could not remove '$dir': $($_.Exception.Message)" }
    }

    [pscustomobject]@{ Removed = $removed; Kept = ($dirs.Count - $removed) }
}

function Get-RecycleBinItem {
    [CmdletBinding()]
    param($Sync)

    $shell = New-Object -ComObject Shell.Application
    try {
        $bin = $shell.Namespace(10)
        if (-not $bin) { return }
        foreach ($item in $bin.Items()) {
            if ($Sync -and $Sync.Cancel) { return }

            $path = [string]$item.Path
            $isFolder = [bool]$item.IsFolder
            $ext = ''
            if (-not $isFolder) { $ext = [System.IO.Path]::GetExtension($path) }

            $name = [string]$item.Name
            if ($ext -and -not $name.EndsWith($ext, [System.StringComparison]::OrdinalIgnoreCase)) { $name += $ext }
            if ($isFolder) { $ext = '(folder)' }

            $length = [long]0
            try { $length = [long]$item.Size } catch { Write-Verbose 'Item size unavailable.' }

            [pscustomobject]@{
                Name          = $name
                DirectoryName = [string]$bin.GetDetailsOf($item, 1)
                Extension     = $ext
                Length        = $length
                FullName      = $path
            }
        }
    }
    finally {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    }
}

# ------------------------------------------------------------------------------------------------
# Shared helpers
# ------------------------------------------------------------------------------------------------
function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { '{0:N2} GB' -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { '{0:N1} MB' -f ($Bytes / 1MB) }
    else { '{0:N0} KB' -f ($Bytes / 1KB) }
}

function Resolve-Extensions {
    [CmdletBinding()]
    param([string[]]$Name)

    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($item in $Name) {
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        foreach ($part in ($item -split '[,;\s]+')) {
            $ext = ($part.Trim() -replace '^[\*\.]+', '').ToLowerInvariant()
            if (-not $ext) { continue }
            if ($ext -notmatch '^[a-z0-9_\-]+$') {
                throw "Invalid extension '$part'. Use letters, digits, '_' or '-' only (for example: pdf, docx)."
            }
            if (-not $list.Contains($ext)) { $list.Add($ext) }
        }
    }
    $list.ToArray()
}

function Test-ProtectedPath {
    <# Returns a reason string if the path must not be cleaned, otherwise $null. #>
    param([string]$Path)

    try { $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\') }
    catch { return 'The folder path is not valid.' }

    $root = [System.IO.Path]::GetPathRoot($full + '\')
    if ($root -and $root.TrimEnd('\') -eq $full) {
        return 'Drive roots and network share roots cannot be cleaned.'
    }

    $deep = @($env:windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData) | Where-Object { $_ }
    foreach ($p in $deep) {
        $pp = $p.TrimEnd('\')
        if ($full -eq $pp -or $full.StartsWith($pp + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            return "System folders cannot be cleaned ($pp)."
        }
    }

    $exact = @($env:USERPROFILE, (Join-Path $env:SystemDrive 'Users')) | Where-Object { $_ }
    foreach ($p in $exact) {
        if ($full -eq $p.TrimEnd('\')) { return 'Choose a subfolder (such as Downloads) rather than the whole profile.' }
    }
    $null
}

function Get-DefaultFolder {
    Join-Path $env:USERPROFILE 'Downloads'
}

function Test-IsElevated {
    try {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        ([System.Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { $false }
}

function Get-TempTarget {
    <# Resolves the fixed temp clean-up targets. These are never user-chosen paths. #>
    param([Parameter(Mandatory)][ValidateSet('UserTemp', 'WindowsTemp')][string]$Mode)

    if ($Mode -eq 'WindowsTemp') {
        $label = 'Windows temp'
        $raw = Join-Path $env:SystemRoot 'Temp'
    }
    else {
        $label = 'user temp'
        $raw = [System.IO.Path]::GetTempPath()
    }

    try { $full = [System.IO.Path]::GetFullPath($raw).TrimEnd('\') }
    catch { throw "The $label folder path is not valid." }

    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        throw "The $label folder '$full' does not exist."
    }
    if ($Mode -eq 'UserTemp') {
        $reason = Test-ProtectedPath -Path $full
        if ($reason) { throw "The user temp folder cannot be cleaned. $reason" }
    }

    [pscustomobject]@{ Path = $full; Label = $label }
}

function Write-TaskLog {
    <# Logs system clean-up tasks to %APPDATA%\CleanFolder (never inside a folder being cleaned). #>
    param([string]$Text)

    $dir = Join-Path $env:APPDATA 'CleanFolder'
    try {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $line = '{0} (Clean-Folder v{1}): {2}' -f (Get-Date -Format 'dddd, d MMMM yyyy'), $ScriptVersion, $Text
        Add-Content -LiteralPath (Join-Path $dir $LogFileName) -Value $line -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not write log file: $($_.Exception.Message)"
    }
}

function Write-CleanupLog {
    param(
        [string]$Folder,
        $Result,
        [bool]$Recurse,
        [bool]$Permanent
    )

    $mode = if ($Permanent) { 'permanent delete' } else { 'Recycle Bin' }
    $rec = if ($Recurse) { 'yes' } else { 'no' }
    $line = 'Clean-up completed on {0} (Clean-Folder v{1}). Mode: {2}. Recurse: {3}. Files deleted: {4}. Total size: {5}. Failures: {6}.' -f `
        (Get-Date -Format 'dddd, d MMMM yyyy'), $ScriptVersion, $mode, $rec, $Result.Deleted, (Format-Size $Result.Bytes), $Result.Failed.Count
    try {
        Add-Content -LiteralPath (Join-Path $Folder $LogFileName) -Value $line -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not write log file: $($_.Exception.Message)"
    }
}

function Write-CleanupSummary {
    param($Result)

    if ($Result.ByExtension.Count -gt 0) {
        Write-Host 'Breakdown of deleted files:'
        $Result.ByExtension.GetEnumerator() |
            Sort-Object { $_.Value.Bytes } -Descending |
            ForEach-Object { [pscustomobject]@{ Type = ('.' + $_.Key); Files = $_.Value.Count; Size = (Format-Size $_.Value.Bytes) } } |
            Format-Table -AutoSize |
            Out-Host
    }
    Write-Host ('Files deleted: {0} | Total size: {1} | Failures: {2}' -f $Result.Deleted, (Format-Size $Result.Bytes), $Result.Failed.Count)
}

# ------------------------------------------------------------------------------------------------
# Mode selection
# ------------------------------------------------------------------------------------------------
$cliTriggers = 'Folder', 'Category', 'Extension', 'Recurse', 'Permanent', 'EverQuestLogs', 'NoGui', 'Version', 'CleanUserTemp', 'CleanWindowsTemp', 'EmptyRecycleBin', 'WhatIf'
$runCli = $false
foreach ($key in $cliTriggers) {
    if ($PSBoundParameters.ContainsKey($key)) { $runCli = $true; break }
}

# ------------------------------------------------------------------------------------------------
# Command-line mode
# ------------------------------------------------------------------------------------------------
$script:CliExit = 0

function Set-CliExit {
    param([int]$Code)
    if ($Code -gt $script:CliExit) { $script:CliExit = $Code }
}

function Invoke-CliTypeCleanup {
    param(
        $Cmdlet,
        [string]$Folder,
        [bool]$FolderBound,
        [string[]]$Category,
        [string[]]$Extension,
        [bool]$Recurse,
        [bool]$Permanent,
        [bool]$EverQuestLogs
    )

    try {
        $names = [System.Collections.Generic.List[string]]::new()
        foreach ($catKey in $Category) {
            $entry = $Catalog | Where-Object { $_.Key -eq $catKey }
            if ($entry) { $names.AddRange([string[]]$entry.Extensions) }
        }
        if ($Extension) { $names.AddRange([string[]]$Extension) }
        if ($EverQuestLogs) { $names.AddRange([string[]]@('txt', 'log')) }
        $exts = @(Resolve-Extensions -Name $names.ToArray())
    }
    catch {
        Write-Error $_.Exception.Message
        Set-CliExit 1
        return
    }

    if ($exts.Count -eq 0) {
        Write-Error 'No file types selected. Use -Category, -Extension or -EverQuestLogs.'
        Set-CliExit 1
        return
    }

    if ($FolderBound) { $targetFolder = $Folder }
    elseif ($EverQuestLogs) { $targetFolder = 'C:\everquest\logs' }
    else { $targetFolder = Get-DefaultFolder }

    $targetFolder = "$targetFolder".Trim().Trim('"')
    if (-not $targetFolder -or -not (Test-Path -LiteralPath $targetFolder -PathType Container)) {
        Write-Error "The directory '$targetFolder' does not exist."
        Set-CliExit 1
        return
    }
    $targetFolder = (Resolve-Path -LiteralPath $targetFolder).ProviderPath

    $reason = Test-ProtectedPath -Path $targetFolder
    if ($reason) {
        Write-Error $reason
        Set-CliExit 1
        return
    }

    $exclude = @((Join-Path $targetFolder $LogFileName))
    if ($PSCommandPath) { $exclude += $PSCommandPath }

    $suffix = if ($Recurse) { ' (including subfolders)' } else { '' }
    Write-Host ("Scanning '{0}' for: {1}{2}" -f $targetFolder, (($exts | ForEach-Object { '.' + $_ }) -join ' '), $suffix)

    $files = @(Find-CleanupFile -Folder $targetFolder -Extensions $exts -Recurse $Recurse -Exclude $exclude)
    if ($files.Count -eq 0) {
        Write-Host 'No matching files found.'
        return
    }

    $action = if ($Permanent) { 'Delete permanently' } else { 'Move to Recycle Bin' }
    $approved = @($files | Where-Object { $Cmdlet.ShouldProcess($_.FullName, $action) })
    if ($approved.Count -eq 0) {
        Write-Host ('{0} matching files found. Nothing was deleted (WhatIf or declined).' -f $files.Count)
        return
    }

    $result = Invoke-CleanupDeletion -Files $approved -Permanent $Permanent -Sync $null
    Write-CleanupSummary -Result $result
    foreach ($failure in $result.Failed) { Write-Warning "Failed: $failure" }

    if ($result.Deleted -gt 0 -or $result.Failed.Count -gt 0) {
        Write-CleanupLog -Folder $targetFolder -Result $result -Recurse $Recurse -Permanent $Permanent
    }
    if ($result.Failed.Count -gt 0) { Set-CliExit 2 }
}

function Invoke-CliTempCleanup {
    param(
        $Cmdlet,
        [Parameter(Mandatory)][ValidateSet('UserTemp', 'WindowsTemp')][string]$Mode
    )

    try { $target = Get-TempTarget -Mode $Mode }
    catch {
        Write-Error $_.Exception.Message
        Set-CliExit 1
        return
    }

    Write-Host ("Scanning {0} '{1}' (everything not in use)" -f $target.Label, $target.Path)
    $files = @(Find-CleanupFile -Folder $target.Path -Recurse $true -AllFiles $true)
    if ($files.Count -eq 0) {
        Write-Host ('Nothing to clean in {0}.' -f $target.Label)
        return
    }

    $total = [long]0
    foreach ($f in $files) { $total += [long]$f.Length }
    $action = 'Delete {0} files ({1}) permanently; files in use are skipped' -f $files.Count, (Format-Size $total)
    if (-not $Cmdlet.ShouldProcess($target.Path, $action)) { return }

    $result = Invoke-CleanupDeletion -Files $files -Permanent $true -PruneRoot $target.Path -Sync $null
    foreach ($failure in $result.Failed) { Write-Verbose "Skipped: $failure" }
    $summary = '{0} files deleted ({1}), {2} skipped (in use or no access), {3} folders removed, {4} folders could not be removed (in use or not empty).' -f `
        $result.Deleted, (Format-Size $result.Bytes), $result.Failed.Count, $result.PrunedDirectories, $result.KeptDirectories
    Write-Host ('{0}: {1}' -f $target.Label, $summary)
    Write-TaskLog -Text ('{0} cleaned (command line): {1}' -f $target.Label, $summary)
}

function Invoke-CliRecycleBin {
    param($Cmdlet)

    try { $items = @(Get-RecycleBinItem) }
    catch {
        Write-Error "Could not read the Recycle Bin: $($_.Exception.Message)"
        Set-CliExit 1
        return
    }
    if ($items.Count -eq 0) {
        Write-Host 'The Recycle Bin is already empty.'
        return
    }

    $total = [long]0
    foreach ($item in $items) { $total += [long]$item.Length }
    $text = '{0} items ({1})' -f $items.Count, (Format-Size $total)
    if (-not $Cmdlet.ShouldProcess('Recycle Bin', "Permanently remove $text")) { return }

    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Host "Recycle Bin emptied: $text."
        Write-TaskLog -Text "Recycle Bin emptied (command line): $text."
    }
    catch {
        Write-Error "Could not empty the Recycle Bin: $($_.Exception.Message)"
        Set-CliExit 2
    }
}

if ($runCli) {
    if ($Version) {
        Write-Output "Clean-Folder $ScriptVersion"
        exit 0
    }

    $anyTask = $CleanUserTemp -or $CleanWindowsTemp -or $EmptyRecycleBin
    $wantTypes = [bool]($Category -or $Extension -or $EverQuestLogs)

    if (-not $anyTask -and -not $wantTypes) {
        Write-Error 'No file types selected. Use -Category, -Extension or -EverQuestLogs, or one of -CleanUserTemp, -CleanWindowsTemp, -EmptyRecycleBin.'
        exit 1
    }

    if ($CleanWindowsTemp -and -not (Test-IsElevated)) {
        Write-Error '-CleanWindowsTemp requires an elevated (Run as administrator) PowerShell session.'
        exit 3
    }

    if ($wantTypes) {
        Invoke-CliTypeCleanup -Cmdlet $PSCmdlet -Folder $Folder -FolderBound ($PSBoundParameters.ContainsKey('Folder')) `
            -Category $Category -Extension $Extension -Recurse $Recurse.IsPresent -Permanent $Permanent.IsPresent `
            -EverQuestLogs $EverQuestLogs.IsPresent
    }
    if ($CleanUserTemp) { Invoke-CliTempCleanup -Cmdlet $PSCmdlet -Mode 'UserTemp' }
    if ($CleanWindowsTemp) { Invoke-CliTempCleanup -Cmdlet $PSCmdlet -Mode 'WindowsTemp' }
    if ($EmptyRecycleBin) { Invoke-CliRecycleBin -Cmdlet $PSCmdlet }

    exit $script:CliExit
}

# ------------------------------------------------------------------------------------------------
# GUI mode
# ------------------------------------------------------------------------------------------------

# WPF requires an STA thread; Windows PowerShell 5.1 starts in MTA by default, so relaunch if needed.
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    if (-not $PSCommandPath) {
        Write-Error 'Please run this script from a saved .ps1 file (or start PowerShell with -STA).'
        exit 1
    }
    $hostExe = (Get-Process -Id $PID).Path
    Start-Process -FilePath $hostExe -WindowStyle Hidden -ArgumentList @('-STA', '-NoProfile', '-File', ('"{0}"' -f $PSCommandPath))
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName Microsoft.VisualBasic

if (-not ('CleanFolder.FileRow' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace CleanFolder
{
    public class FileRow
    {
        public string Name { get; set; }
        public string Folder { get; set; }
        public string Type { get; set; }
        public string SizeText { get; set; }
        public long SizeBytes { get; set; }
    }

    public static class DwmTheme
    {
        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);

        public static void SetDarkTitleBar(IntPtr hwnd, bool dark)
        {
            int v = dark ? 1 : 0;
            if (DwmSetWindowAttribute(hwnd, 20, ref v, sizeof(int)) != 0)
            {
                DwmSetWindowAttribute(hwnd, 19, ref v, sizeof(int));
            }
        }
    }
}
'@
}

$settingsPath = Join-Path $env:APPDATA 'CleanFolder\settings.json'

$palettes = @{
    Dark  = [ordered]@{
        WindowBg = '#14161B'; Surface = '#1D2027'; SurfaceAlt = '#262A33'; Border = '#343A46'
        TextPrimary = '#E8EAEF'; TextMuted = '#9AA2B1'; Accent = '#5AA2FF'; AccentText = '#0A1220'
        Danger = '#C4372F'; DangerText = '#FFFFFF'; ControlBg = '#272B34'; HoverOverlay = '#FFFFFF'
        Selection = '#2C4A78'; GridAlt = '#20242B'; CheckBorder = '#6B7385'; ScrollThumb = '#4A5160'
    }
    Light = [ordered]@{
        WindowBg = '#F1F3F7'; Surface = '#FFFFFF'; SurfaceAlt = '#EEF1F6'; Border = '#D6DBE4'
        TextPrimary = '#1A1F29'; TextMuted = '#5E6778'; Accent = '#1F6FEB'; AccentText = '#FFFFFF'
        Danger = '#C62828'; DangerText = '#FFFFFF'; ControlBg = '#FFFFFF'; HoverOverlay = '#000000'
        Selection = '#D3E5FF'; GridAlt = '#F6F8FB'; CheckBorder = '#8A93A5'; ScrollThumb = '#B7BECB'
    }
}

function New-ThemeDictionary {
    param([System.Collections.IDictionary]$Palette)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">')
    foreach ($name in $Palette.Keys) {
        [void]$sb.Append(('<SolidColorBrush x:Key="{0}" Color="{1}"/>' -f $name, $Palette[$name]))
    }
    [void]$sb.Append('</ResourceDictionary>')
    [System.Windows.Markup.XamlReader]::Parse($sb.ToString())
}

function Get-SystemTheme {
    try {
        $v = Get-ItemPropertyValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop
        if ($v -eq 0) { 'Dark' } else { 'Light' }
    }
    catch { 'Light' }
}

function Get-CleanerSettings {
    $settings = [ordered]@{ Theme = ''; Folder = ''; Recurse = $false; Permanent = $false; Custom = ''; Extensions = @() }
    try {
        if (Test-Path -LiteralPath $settingsPath) {
            $json = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            foreach ($name in @($settings.Keys)) {
                $prop = $json.PSObject.Properties[$name]
                if ($prop -and $null -ne $prop.Value) { $settings[$name] = $prop.Value }
            }
        }
    }
    catch { Write-Verbose "Could not read settings: $($_.Exception.Message)" }
    $settings
}

function Save-CleanerSettings {
    param([System.Collections.IDictionary]$Settings)
    try {
        $dir = Split-Path -Path $settingsPath -Parent
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $Settings | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    }
    catch { Write-Verbose "Could not save settings: $($_.Exception.Message)" }
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Folder Clean-Up" Width="1060" Height="860" MinWidth="880" MinHeight="720"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" FontSize="13"
        Background="{DynamicResource WindowBg}" Foreground="{DynamicResource TextPrimary}"
        UseLayoutRounding="True" SnapsToDevicePixels="True">
  <Window.Resources>

    <!-- Scrollbars -->
    <Style x:Key="ScrollThumbStyle" TargetType="Thumb">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Thumb">
            <Border Background="{DynamicResource ScrollThumb}" CornerRadius="4" Margin="2"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="ScrollPageButton" TargetType="RepeatButton">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RepeatButton">
            <Border Background="Transparent"/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <ControlTemplate x:Key="VScrollTemplate" TargetType="ScrollBar">
      <Grid Background="Transparent">
        <Track x:Name="PART_Track" IsDirectionReversed="True">
          <Track.DecreaseRepeatButton>
            <RepeatButton Style="{StaticResource ScrollPageButton}" Command="ScrollBar.PageUpCommand"/>
          </Track.DecreaseRepeatButton>
          <Track.Thumb>
            <Thumb Style="{StaticResource ScrollThumbStyle}"/>
          </Track.Thumb>
          <Track.IncreaseRepeatButton>
            <RepeatButton Style="{StaticResource ScrollPageButton}" Command="ScrollBar.PageDownCommand"/>
          </Track.IncreaseRepeatButton>
        </Track>
      </Grid>
    </ControlTemplate>
    <ControlTemplate x:Key="HScrollTemplate" TargetType="ScrollBar">
      <Grid Background="Transparent">
        <Track x:Name="PART_Track">
          <Track.DecreaseRepeatButton>
            <RepeatButton Style="{StaticResource ScrollPageButton}" Command="ScrollBar.PageLeftCommand"/>
          </Track.DecreaseRepeatButton>
          <Track.Thumb>
            <Thumb Style="{StaticResource ScrollThumbStyle}"/>
          </Track.Thumb>
          <Track.IncreaseRepeatButton>
            <RepeatButton Style="{StaticResource ScrollPageButton}" Command="ScrollBar.PageRightCommand"/>
          </Track.IncreaseRepeatButton>
        </Track>
      </Grid>
    </ControlTemplate>
    <Style TargetType="ScrollBar">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Width" Value="12"/>
      <Setter Property="Template" Value="{StaticResource VScrollTemplate}"/>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto"/>
          <Setter Property="Height" Value="12"/>
          <Setter Property="Template" Value="{StaticResource HScrollTemplate}"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- Buttons: one template, hover/pressed done with an overlay so every variant themes correctly -->
    <Style x:Key="BtnBase" TargetType="Button">
      <Setter Property="Background" Value="{DynamicResource ControlBg}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Border}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="MinWidth" Value="90"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="True"/>
              </Border>
              <Border x:Name="Overlay" Background="{DynamicResource HoverOverlay}" CornerRadius="6" Opacity="0" IsHitTestVisible="False"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Overlay" Property="Opacity" Value="0.12"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Overlay" Property="Opacity" Value="0.22"/>
              </Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{DynamicResource Accent}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.45"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button" BasedOn="{StaticResource BtnBase}"/>
    <Style x:Key="PrimaryButton" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="{DynamicResource Accent}"/>
      <Setter Property="Foreground" Value="{DynamicResource AccentText}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Accent}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="{DynamicResource Danger}"/>
      <Setter Property="Foreground" Value="{DynamicResource DangerText}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Danger}"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="LinkButton" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{DynamicResource Accent}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="8,3"/>
      <Setter Property="MinWidth" Value="0"/>
      <Setter Property="FontSize" Value="12"/>
    </Style>

    <!-- Check boxes -->
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
      <Setter Property="Margin" Value="0,3,12,3"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <StackPanel Orientation="Horizontal" Background="Transparent">
              <Grid Width="18" Height="18" VerticalAlignment="Center">
                <Border x:Name="Box" CornerRadius="4" BorderThickness="1.5" BorderBrush="{DynamicResource CheckBorder}" Background="{DynamicResource ControlBg}"/>
                <Path x:Name="Tick" Data="M4,9 L7.5,12.5 L14,5.5" Stroke="{DynamicResource AccentText}" StrokeThickness="2"
                      StrokeStartLineCap="Round" StrokeEndLineCap="Round" StrokeLineJoin="Round" Visibility="Collapsed"/>
              </Grid>
              <ContentPresenter Margin="8,0,0,0" VerticalAlignment="Center" RecognizesAccessKey="True"/>
            </StackPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Accent}"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="{DynamicResource Accent}"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Accent}"/>
                <Setter TargetName="Tick" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Group boxes -->
    <Style TargetType="GroupBox">
      <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
      <Setter Property="Margin" Value="0,0,12,12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="GroupBox">
            <Border Background="{DynamicResource Surface}" BorderBrush="{DynamicResource Border}" BorderThickness="1" CornerRadius="8">
              <DockPanel>
                <Border DockPanel.Dock="Top" Padding="14,10,14,4">
                  <ContentPresenter ContentSource="Header" RecognizesAccessKey="False"
                                    TextElement.FontWeight="SemiBold" TextElement.FontSize="14"
                                    TextElement.Foreground="{DynamicResource Accent}"/>
                </Border>
                <ContentPresenter Margin="14,2,14,12"/>
              </DockPanel>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Text boxes -->
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="{DynamicResource ControlBg}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Border}"/>
      <Setter Property="CaretBrush" Value="{DynamicResource TextPrimary}"/>
      <Setter Property="SelectionBrush" Value="{DynamicResource Accent}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
              <ScrollViewer x:Name="PART_ContentHost" Focusable="False" Margin="{TemplateBinding Padding}"
                            HorizontalScrollBarVisibility="Hidden" VerticalScrollBarVisibility="Hidden"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocused" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="{DynamicResource Accent}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Progress bar -->
    <Style TargetType="ProgressBar">
      <Setter Property="Height" Value="8"/>
      <Setter Property="Background" Value="{DynamicResource SurfaceAlt}"/>
      <Setter Property="Foreground" Value="{DynamicResource Accent}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Grid>
              <Border x:Name="PART_Track" Background="{TemplateBinding Background}" CornerRadius="4"/>
              <Border x:Name="PART_Indicator" Background="{TemplateBinding Foreground}" CornerRadius="4" HorizontalAlignment="Left"/>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Tooltips -->
    <Style TargetType="ToolTip">
      <Setter Property="Background" Value="{DynamicResource SurfaceAlt}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Border}"/>
    </Style>

    <!-- Data grid -->
    <Style TargetType="DataGrid">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
      <Setter Property="RowBackground" Value="Transparent"/>
      <Setter Property="AlternatingRowBackground" Value="{DynamicResource GridAlt}"/>
      <Setter Property="HorizontalGridLinesBrush" Value="{DynamicResource Border}"/>
      <Setter Property="BorderThickness" Value="0"/>
    </Style>
    <Style TargetType="DataGridColumnHeader">
      <Setter Property="Background" Value="{DynamicResource SurfaceAlt}"/>
      <Setter Property="Foreground" Value="{DynamicResource TextMuted}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Border}"/>
      <Setter Property="BorderThickness" Value="0,0,0,1"/>
      <Setter Property="Padding" Value="10,8"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style TargetType="DataGridRow">
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="{DynamicResource Selection}"/>
          <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="DataGridCell">
      <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="{DynamicResource Selection}"/>
          <Setter Property="Foreground" Value="{DynamicResource TextPrimary}"/>
          <Setter Property="BorderThickness" Value="0"/>
        </Trigger>
      </Style.Triggers>
    </Style>

  </Window.Resources>

  <Grid Margin="20,16,20,14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="1.1*" MinHeight="170"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="1*" MinHeight="160"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Grid Grid.Row="0" Margin="0,0,0,14">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel>
        <TextBlock FontSize="24" FontWeight="SemiBold" Text="&#x1F9F9;  Folder Clean-Up"/>
        <TextBlock Margin="0,2,0,0" Foreground="{DynamicResource TextMuted}" Text="Pick file types, scan to preview, then clean up."/>
      </StackPanel>
      <Button x:Name="ThemeButton" Grid.Column="1" VerticalAlignment="Center" MinWidth="140"/>
    </Grid>

    <!-- Folder and options -->
    <Border Grid.Row="1" Background="{DynamicResource Surface}" BorderBrush="{DynamicResource Border}"
            BorderThickness="1" CornerRadius="8" Padding="14" Margin="0,0,0,12">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid Grid.Row="0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock Text="Folder" VerticalAlignment="Center" Margin="0,0,12,0" FontWeight="SemiBold"/>
          <TextBox x:Name="FolderBox" Grid.Column="1" VerticalContentAlignment="Center"/>
          <Button x:Name="BrowseButton" Grid.Column="2" Content="Browse..." Margin="10,0,0,0" MinWidth="90"/>
        </Grid>
        <WrapPanel Grid.Row="1" Margin="0,12,0,0">
          <CheckBox x:Name="RecurseCheck" Content="Include subfolders" VerticalAlignment="Center" Margin="0,0,24,0"/>
          <CheckBox x:Name="PermanentCheck" Content="Delete permanently (skip Recycle Bin)" VerticalAlignment="Center" Margin="0,0,24,0"/>
          <TextBlock Text="Other extensions" VerticalAlignment="Center" Margin="0,0,8,0" Foreground="{DynamicResource TextMuted}"/>
          <TextBox x:Name="CustomBox" Width="220" VerticalContentAlignment="Center"
                   ToolTip="Comma or space separated, for example: rtf, sqlite"/>
        </WrapPanel>
      </Grid>
    </Border>

    <!-- Categories (group boxes are added in code) -->
    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
      <WrapPanel x:Name="CategoryPanel"/>
    </ScrollViewer>

    <!-- System clean-up -->
    <Border Grid.Row="3" Background="{DynamicResource Surface}" BorderBrush="{DynamicResource Border}"
            BorderThickness="1" CornerRadius="8" Padding="12,10,12,2" Margin="0,0,0,12">
      <WrapPanel x:Name="QuickPanel">
        <TextBlock Text="System clean-up" VerticalAlignment="Center" FontWeight="SemiBold" Margin="2,0,16,8"/>
        <Button x:Name="UserTempButton" Content="Clean user temp" Margin="0,0,10,8"/>
        <Button x:Name="WindowsTempButton" Content="Clean Windows temp" Margin="0,0,10,8"/>
        <Button x:Name="RestartAdminButton" Margin="0,0,10,8" Visibility="Collapsed"/>
        <Button x:Name="BinButton" Content="Empty Recycle Bin" Margin="0,0,10,8"/>
      </WrapPanel>
    </Border>

    <!-- Actions -->
    <Grid Grid.Row="4" Margin="0,4,0,12">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <StackPanel Orientation="Horizontal">
        <Button x:Name="ScanButton" Content="Scan" Style="{StaticResource PrimaryButton}" MinWidth="110"/>
        <Button x:Name="DeleteButton" Content="Move to Recycle Bin" Margin="10,0,0,0" MinWidth="170"/>
        <Button x:Name="CancelButton" Content="Cancel" Margin="10,0,0,0"/>
      </StackPanel>
      <ProgressBar x:Name="WorkProgress" Grid.Column="1" Margin="18,0,0,0" VerticalAlignment="Center" Minimum="0" Maximum="1" Value="0"/>
    </Grid>

    <!-- Results -->
    <Border Grid.Row="5" Background="{DynamicResource Surface}" BorderBrush="{DynamicResource Border}"
            BorderThickness="1" CornerRadius="8" ClipToBounds="True">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <TextBlock x:Name="SummaryText" Margin="14,10,14,8" Foreground="{DynamicResource TextMuted}" TextTrimming="CharacterEllipsis"/>
        <Grid Grid.Row="1">
          <DataGrid x:Name="ResultsGrid" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False"
                    CanUserDeleteRows="False" CanUserResizeRows="False" HeadersVisibility="Column"
                    GridLinesVisibility="Horizontal" SelectionMode="Extended" SelectionUnit="FullRow"
                    RowHeaderWidth="0" EnableRowVirtualization="True">
            <DataGrid.Columns>
              <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="2*">
                <DataGridTextColumn.ElementStyle>
                  <Style TargetType="TextBlock">
                    <Setter Property="TextTrimming" Value="CharacterEllipsis"/>
                  </Style>
                </DataGridTextColumn.ElementStyle>
              </DataGridTextColumn>
              <DataGridTextColumn Header="Folder" Binding="{Binding Folder}" Width="3*">
                <DataGridTextColumn.ElementStyle>
                  <Style TargetType="TextBlock">
                    <Setter Property="TextTrimming" Value="CharacterEllipsis"/>
                  </Style>
                </DataGridTextColumn.ElementStyle>
              </DataGridTextColumn>
              <DataGridTextColumn Header="Type" Binding="{Binding Type}" Width="80"/>
              <DataGridTextColumn Header="Size" Binding="{Binding SizeText}" SortMemberPath="SizeBytes" Width="110">
                <DataGridTextColumn.ElementStyle>
                  <Style TargetType="TextBlock">
                    <Setter Property="HorizontalAlignment" Value="Right"/>
                  </Style>
                </DataGridTextColumn.ElementStyle>
              </DataGridTextColumn>
            </DataGrid.Columns>
          </DataGrid>
          <TextBlock x:Name="EmptyText" HorizontalAlignment="Center" VerticalAlignment="Center" IsHitTestVisible="False"
                     Foreground="{DynamicResource TextMuted}" Text="Choose file types above, then click Scan to preview what will be cleaned."/>
        </Grid>
      </Grid>
    </Border>

    <!-- Status -->
    <TextBlock x:Name="StatusText" Grid.Row="6" Margin="2,10,0,0" Foreground="{DynamicResource TextMuted}" TextTrimming="CharacterEllipsis" Text="Ready."/>
  </Grid>
</Window>
'@

try {
    $window = [System.Windows.Markup.XamlReader]::Parse($xaml)
}
catch {
    Write-Error "Failed to build the window: $($_.Exception.Message)"
    exit 1
}

$window.Title = "Folder Clean-Up v$ScriptVersion"

# Control references
$ThemeButton = $window.FindName('ThemeButton')
$FolderBox = $window.FindName('FolderBox')
$BrowseButton = $window.FindName('BrowseButton')
$RecurseCheck = $window.FindName('RecurseCheck')
$PermanentCheck = $window.FindName('PermanentCheck')
$CustomBox = $window.FindName('CustomBox')
$CategoryPanel = $window.FindName('CategoryPanel')
$ScanButton = $window.FindName('ScanButton')
$DeleteButton = $window.FindName('DeleteButton')
$CancelButton = $window.FindName('CancelButton')
$WorkProgress = $window.FindName('WorkProgress')
$ResultsGrid = $window.FindName('ResultsGrid')
$EmptyText = $window.FindName('EmptyText')
$SummaryText = $window.FindName('SummaryText')
$StatusText = $window.FindName('StatusText')
$QuickPanel = $window.FindName('QuickPanel')
$UserTempButton = $window.FindName('UserTempButton')
$WindowsTempButton = $window.FindName('WindowsTempButton')
$RestartAdminButton = $window.FindName('RestartAdminButton')
$BinButton = $window.FindName('BinButton')

$settings = Get-CleanerSettings
$state = @{
    Busy        = $false
    Kind        = ''
    Sync        = $null
    PS          = $null
    RS          = $null
    Handle      = $null
    Items       = $null
    ScanFolder  = ''
    ScanRecurse = $false
    Permanent   = $false
    Theme       = 'Light'
    Mode        = 'Types'
    IsElevated  = $false
    BinText     = ''
}

# ------------------------------------------------------------------------------------------------
# GUI helper functions
# ------------------------------------------------------------------------------------------------
function Show-Message {
    param(
        [string]$Text,
        [string]$Title = 'Folder Clean-Up',
        [System.Windows.MessageBoxImage]$Icon = [System.Windows.MessageBoxImage]::Information
    )
    [void][System.Windows.MessageBox]::Show($window, $Text, $Title, [System.Windows.MessageBoxButton]::OK, $Icon)
}

function Set-TitleBarTheme {
    try {
        $hwnd = ([System.Windows.Interop.WindowInteropHelper]::new($window)).Handle
        if ($hwnd -ne [IntPtr]::Zero) {
            [CleanFolder.DwmTheme]::SetDarkTitleBar($hwnd, ($state.Theme -eq 'Dark'))
        }
    }
    catch { Write-Verbose "Title bar theme not applied: $($_.Exception.Message)" }
}

function Set-Theme {
    param([ValidateSet('Dark', 'Light')][string]$Name)
    $state.Theme = $Name
    $window.Resources.MergedDictionaries.Clear()
    $window.Resources.MergedDictionaries.Add((New-ThemeDictionary -Palette $palettes[$Name]))
    if ($Name -eq 'Dark') {
        $ThemeButton.Content = [char]::ConvertFromUtf32(0x2600) + '  Light mode'
    }
    else {
        $ThemeButton.Content = [char]::ConvertFromUtf32(0x1F319) + '  Dark mode'
    }
    Set-TitleBarTheme
}

function Update-DeleteButton {
    $danger = $true
    switch ($state.Mode) {
        'UserTemp'    { $DeleteButton.Content = 'Delete user temp permanently' }
        'WindowsTemp' { $DeleteButton.Content = 'Delete Windows temp permanently' }
        'RecycleBin'  { $DeleteButton.Content = 'Empty Recycle Bin' }
        default {
            if ($PermanentCheck.IsChecked) { $DeleteButton.Content = 'Delete permanently' }
            else { $DeleteButton.Content = 'Move to Recycle Bin'; $danger = $false }
        }
    }
    if ($danger) { $DeleteButton.Style = $window.FindResource('DangerButton') }
    else { $DeleteButton.Style = $window.FindResource('BtnBase') }
}

function Update-Buttons {
    Update-DeleteButton
    $busy = [bool]$state.Busy
    $hasItems = ($null -ne $state.Items) -and ($state.Items.Count -gt 0)
    $ScanButton.IsEnabled = -not $busy
    $DeleteButton.IsEnabled = (-not $busy) -and $hasItems
    # Emptying the Recycle Bin cannot be interrupted once started
    $CancelButton.IsEnabled = $busy -and ($state.Kind -ne 'BinEmpty')
    foreach ($control in @($FolderBox, $BrowseButton, $RecurseCheck, $PermanentCheck, $CustomBox, $CategoryPanel, $QuickPanel)) {
        $control.IsEnabled = -not $busy
    }
}

function Show-Rows {
    param($Files)
    $rows = [System.Collections.Generic.List[object]]::new()
    $total = [long]0
    foreach ($f in $Files) {
        $total += [long]$f.Length
        $rows.Add([CleanFolder.FileRow]@{
                Name      = $f.Name
                Folder    = $f.DirectoryName
                Type      = $f.Extension.ToLowerInvariant()
                SizeText  = (Format-Size $f.Length)
                SizeBytes = [long]$f.Length
            })
    }
    $ResultsGrid.ItemsSource = $rows
    if ($rows.Count -eq 0) {
        $EmptyText.Visibility = [System.Windows.Visibility]::Visible
        $SummaryText.Text = ''
    }
    else {
        $EmptyText.Visibility = [System.Windows.Visibility]::Collapsed
        $top = @($Files | Group-Object { $_.Extension.ToLowerInvariant() } | Sort-Object Count -Descending |
                Select-Object -First 6 | ForEach-Object { '{0} x{1}' -f $_.Name, $_.Count })
        $SummaryText.Text = ('{0} files   |   {1}   |   {2}' -f $rows.Count, (Format-Size $total), ($top -join ', '))
    }
}

function Clear-Results {
    param([string]$Message = 'Choose file types above, then click Scan to preview what will be cleaned.')
    $state.Items = $null
    $state.Mode = 'Types'
    $ResultsGrid.ItemsSource = $null
    $SummaryText.Text = ''
    $EmptyText.Text = $Message
    $EmptyText.Visibility = [System.Windows.Visibility]::Visible
    $WorkProgress.Value = 0
}

function Reset-ScanResults {
    if ($state.Busy) { return }
    if ($null -ne $state.Items) {
        Clear-Results
        $StatusText.Text = 'Selection changed. Scan again to refresh the list.'
    }
    Update-Buttons
}

function Get-SelectedExtensions {
    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $checkBoxes.GetEnumerator()) {
        if ($entry.Value.IsChecked) { $names.Add($entry.Key) }
    }
    if ($CustomBox.Text) { $names.Add($CustomBox.Text) }
    Resolve-Extensions -Name $names.ToArray()
}

function Start-Worker {
    param(
        [string]$Kind,
        [scriptblock]$Script,
        [hashtable]$Arguments
    )

    $state.Busy = $true
    $state.Kind = $Kind
    $state.Sync = [hashtable]::Synchronized(@{
            Cancel   = $false
            Finished = $false
            Count    = 0
            Done     = 0
            Total    = 0
            Current  = ''
            Result   = $null
            Error    = $null
        })
    $Arguments['Sync'] = $state.Sync

    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    foreach ($fn in 'Find-CleanupFile', 'Remove-CleanupFile', 'Invoke-CleanupDeletion', 'Remove-EmptyDirectory', 'Get-RecycleBinItem') {
        $definition = (Get-Item -LiteralPath "function:$fn").Definition
        $iss.Commands.Add([System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($fn, $definition))
    }
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    $rs.ApartmentState = [System.Threading.ApartmentState]::STA
    $rs.Open()

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($Script.ToString()).AddParameters($Arguments)

    $state.RS = $rs
    $state.PS = $ps
    $state.Handle = $ps.BeginInvoke()

    Update-Buttons
    $timer.Start()
}

function Complete-Worker {
    $errorText = $null
    try { [void]$state.PS.EndInvoke($state.Handle) } catch { $errorText = $_.Exception.Message }
    try { $state.PS.Dispose(); $state.RS.Close(); $state.RS.Dispose() } catch { Write-Verbose 'Runspace cleanup failed.' }

    $kind = $state.Kind
    $mode = $state.Mode
    $sync = $state.Sync
    $state.Busy = $false
    $state.PS = $null
    $state.RS = $null
    if (-not $errorText -and $sync.Error) { $errorText = $sync.Error }

    if ($errorText) {
        $StatusText.Text = 'Error: ' + $errorText
        Update-Buttons
        Show-Message -Text $errorText -Icon Error
        return
    }

    $label = 'the selected folder'
    if ($mode -eq 'UserTemp') { $label = 'user temp' }
    elseif ($mode -eq 'WindowsTemp') { $label = 'Windows temp' }

    switch ($kind) {
        'Scan' {
            $files = $sync.Result
            if ($sync.Cancel) {
                Clear-Results
                $StatusText.Text = 'Scan cancelled.'
            }
            elseif ($null -eq $files -or $files.Count -eq 0) {
                if ($mode -eq 'Types') { $none = 'No matching files found.' } else { $none = "Nothing to clean in $label." }
                Clear-Results -Message $none
                $StatusText.Text = $none
            }
            else {
                $state.Items = $files
                Show-Rows -Files $files
                if ($mode -eq 'Types') {
                    $StatusText.Text = 'Scan complete. Review the list, then choose how to clean up.'
                }
                else {
                    $StatusText.Text = "Preview of $label. Click the red button to permanently delete these files (files in use are skipped)."
                }
            }
        }

        'BinScan' {
            $items = $sync.Result
            if ($sync.Cancel) {
                Clear-Results
                $StatusText.Text = 'Cancelled.'
            }
            elseif ($null -eq $items -or $items.Count -eq 0) {
                Clear-Results -Message 'The Recycle Bin is empty.'
                $StatusText.Text = 'The Recycle Bin is empty.'
            }
            else {
                $state.Items = $items
                Show-Rows -Files $items
                $StatusText.Text = 'Recycle Bin contents. Click the red button to empty it permanently (this cannot be undone).'
            }
        }

        'Delete' {
            $res = $sync.Result
            if ($mode -eq 'Types') {
                if ($state.Permanent) { $verb = 'Permanently deleted' } else { $verb = 'Moved to the Recycle Bin' }
                $text = '{0}: {1} files ({2}).' -f $verb, $res.Deleted, (Format-Size $res.Bytes)
            }
            else {
                $text = 'Deleted {0} files ({1}) from {2}.' -f $res.Deleted, (Format-Size $res.Bytes), $label
                if ($res.PrunedDirectories -gt 0) { $text += " Removed $($res.PrunedDirectories) folders." }
                if ($res.KeptDirectories -gt 0) { $text += " $($res.KeptDirectories) folders could not be removed (in use or not empty)." }
            }
            if ($res.Cancelled) { $text += ' Cancelled before finishing.' }
            if ($res.Failed.Count -gt 0) {
                if ($mode -eq 'Types') { $text += " $($res.Failed.Count) failed." }
                else { $text += " $($res.Failed.Count) skipped (in use or no access)." }
            }

            $remaining = @($state.Items | Where-Object { -not $res.DeletedPaths.Contains($_.FullName) })
            if ($remaining.Count -gt 0) {
                $state.Items = [System.Collections.Generic.List[object]]::new([object[]]$remaining)
                Show-Rows -Files $remaining
            }
            else {
                Clear-Results -Message 'All matching files were cleaned up.'
            }
            $WorkProgress.Value = $WorkProgress.Maximum
            $StatusText.Text = $text

            if ($res.Deleted -gt 0 -or $res.Failed.Count -gt 0) {
                if ($mode -eq 'Types') {
                    Write-CleanupLog -Folder $state.ScanFolder -Result $res -Recurse $state.ScanRecurse -Permanent $state.Permanent
                }
                else {
                    Write-TaskLog -Text ('{0} cleaned: {1}' -f $label, $text)
                }
            }
            if ($mode -eq 'Types' -and $res.Failed.Count -gt 0) {
                $shown = @($res.Failed | Select-Object -First 10) -join "`n"
                $more = ''
                if ($res.Failed.Count -gt 10) { $more = "`n...and $($res.Failed.Count - 10) more." }
                Update-Buttons
                Show-Message -Text ("Some files could not be deleted:`n`n" + $shown + $more) -Icon Warning
            }
        }

        'BinEmpty' {
            Clear-Results -Message 'The Recycle Bin was emptied.'
            $WorkProgress.Value = $WorkProgress.Maximum
            $StatusText.Text = 'Recycle Bin emptied. ' + $state.BinText
            Write-TaskLog -Text ('Recycle Bin emptied. {0}' -f $state.BinText)
        }
    }
    Update-Buttons
}

function Update-Progress {
    $sync = $state.Sync
    if (-not $sync) { return }

    switch ($state.Kind) {
        'Scan' { $StatusText.Text = 'Scanning... {0} matching files found' -f $sync.Count }
        'BinScan' { $StatusText.Text = 'Reading the Recycle Bin... {0} items' -f $sync.Count }
        'BinEmpty' { $StatusText.Text = 'Emptying the Recycle Bin...' }
        default {
            $total = [int]$sync.Total
            if ($total -gt 0) { $WorkProgress.Maximum = $total }
            $WorkProgress.Value = [int]$sync.Done
            $StatusText.Text = 'Cleaning up... {0} of {1}' -f $sync.Done, $total
        }
    }

    if ($sync.Finished) {
        $timer.Stop()
        Complete-Worker
    }
}

# Background work scripts (run inside the worker runspace)
$scanWork = {
    param($Folder, $Extensions, $Recurse, $Exclude, $AllFiles, $Sync)
    try {
        $found = [System.Collections.Generic.List[object]]::new()
        foreach ($file in (Find-CleanupFile -Folder $Folder -Extensions $Extensions -Recurse $Recurse -Exclude $Exclude -AllFiles ([bool]$AllFiles) -Sync $Sync)) {
            $found.Add($file)
            $Sync.Count = $found.Count
        }
        $Sync.Result = $found
    }
    catch { $Sync.Error = $_.Exception.Message }
    finally { $Sync.Finished = $true }
}

$deleteWork = {
    param($Files, $Permanent, $PruneRoot, $Sync)
    try {
        $Sync.Result = Invoke-CleanupDeletion -Files $Files -Permanent $Permanent -PruneRoot $PruneRoot -Sync $Sync
    }
    catch { $Sync.Error = $_.Exception.Message }
    finally { $Sync.Finished = $true }
}

$binScanWork = {
    param($Sync)
    try {
        $found = [System.Collections.Generic.List[object]]::new()
        foreach ($item in (Get-RecycleBinItem -Sync $Sync)) {
            $found.Add($item)
            $Sync.Count = $found.Count
        }
        $Sync.Result = $found
    }
    catch { $Sync.Error = $_.Exception.Message }
    finally { $Sync.Finished = $true }
}

$binEmptyWork = {
    param($Sync)
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        $Sync.Result = $true
    }
    catch { $Sync.Error = $_.Exception.Message }
    finally { $Sync.Finished = $true }
}

$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(150)
$timer.Add_Tick({ Update-Progress })

# ------------------------------------------------------------------------------------------------
# Build the category group boxes
# ------------------------------------------------------------------------------------------------
$checkBoxes = @{}
$savedExtensions = @($settings.Extensions)

foreach ($cat in $Catalog) {
    $group = [System.Windows.Controls.GroupBox]::new()
    $group.Header = [char]::ConvertFromUtf32([int]$cat.Icon) + '  ' + $cat.Title
    $group.Width = 305

    $stack = [System.Windows.Controls.StackPanel]::new()
    $groupBoxes = [System.Collections.Generic.List[object]]::new()

    # Short extensions sit in an aligned 3-column grid; long ones (8+ characters) follow in a 2-column grid
    $shortGrid = [System.Windows.Controls.Primitives.UniformGrid]::new()
    $shortGrid.Columns = 3
    $longGrid = [System.Windows.Controls.Primitives.UniformGrid]::new()
    $longGrid.Columns = 2

    $toolbar = [System.Windows.Controls.StackPanel]::new()
    $toolbar.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $toolbar.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
    $toolbar.Margin = [System.Windows.Thickness]::new(0, 0, -8, 2)

    $allButton = [System.Windows.Controls.Button]::new()
    $allButton.Content = 'All'
    $allButton.Style = $window.FindResource('LinkButton')
    $allButton.Tag = $groupBoxes
    $allButton.Add_Click({
            param($sender, $e)
            foreach ($child in $sender.Tag) { $child.IsChecked = $true }
        })

    $noneButton = [System.Windows.Controls.Button]::new()
    $noneButton.Content = 'None'
    $noneButton.Style = $window.FindResource('LinkButton')
    $noneButton.Tag = $groupBoxes
    $noneButton.Add_Click({
            param($sender, $e)
            foreach ($child in $sender.Tag) { $child.IsChecked = $false }
        })

    [void]$toolbar.Children.Add($allButton)
    [void]$toolbar.Children.Add($noneButton)

    # Alphabetical order; the short/long split below keeps each grid sorted on its own
    foreach ($ext in @($cat.Extensions | Sort-Object)) {
        $box = [System.Windows.Controls.CheckBox]::new()
        $box.Content = '.' + $ext
        $box.Tag = $ext
        $box.Margin = [System.Windows.Thickness]::new(0, 3, 0, 3)
        $box.IsChecked = ($savedExtensions -contains $ext)
        if ($ext.Length -ge 8) { [void]$longGrid.Children.Add($box) } else { [void]$shortGrid.Children.Add($box) }
        $groupBoxes.Add($box)
        $checkBoxes[$ext] = $box
    }

    [void]$stack.Children.Add($toolbar)
    [void]$stack.Children.Add($shortGrid)
    [void]$stack.Children.Add($longGrid)
    $group.Content = $stack
    [void]$CategoryPanel.Children.Add($group)
}

# ------------------------------------------------------------------------------------------------
# Restore settings
# ------------------------------------------------------------------------------------------------
if ($settings.Folder) { $FolderBox.Text = [string]$settings.Folder } else { $FolderBox.Text = Get-DefaultFolder }
$RecurseCheck.IsChecked = [bool]$settings.Recurse
$PermanentCheck.IsChecked = [bool]$settings.Permanent
$CustomBox.Text = [string]$settings.Custom

$initialTheme = Get-SystemTheme
if ($settings.Theme -eq 'Dark' -or $settings.Theme -eq 'Light') { $initialTheme = [string]$settings.Theme }
Set-Theme -Name $initialTheme

# System clean-up buttons: Windows temp needs an elevated session
$state.IsElevated = Test-IsElevated
$UserTempButton.ToolTip = 'Delete everything in your temp folder that is not in use (you get a preview first).'
$BinButton.ToolTip = 'Preview the Recycle Bin contents, then empty it permanently.'
$RestartAdminButton.Content = [char]::ConvertFromUtf32(0x1F6E1) + '  Restart as administrator'
[System.Windows.Controls.ToolTipService]::SetShowOnDisabled($WindowsTempButton, $true)
if ($state.IsElevated) {
    $WindowsTempButton.ToolTip = 'Delete everything in C:\Windows\Temp that is not in use (you get a preview first).'
}
else {
    $WindowsTempButton.IsEnabled = $false
    $WindowsTempButton.ToolTip = 'Requires administrator rights. Use "Restart as administrator".'
    $RestartAdminButton.Visibility = [System.Windows.Visibility]::Visible
    if (-not $PSCommandPath) { $RestartAdminButton.IsEnabled = $false }
}

Clear-Results
Update-Buttons

# ------------------------------------------------------------------------------------------------
# Events
# ------------------------------------------------------------------------------------------------
$window.Add_SourceInitialized({ Set-TitleBarTheme })

$ThemeButton.Add_Click({
        if ($state.Theme -eq 'Dark') { Set-Theme -Name 'Light' } else { Set-Theme -Name 'Dark' }
    })

# Any change to the file selection invalidates the current scan results
$changeHandler = [System.Windows.RoutedEventHandler] { param($sender, $e) Reset-ScanResults }
$CategoryPanel.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::CheckedEvent, $changeHandler)
$CategoryPanel.AddHandler([System.Windows.Controls.Primitives.ToggleButton]::UncheckedEvent, $changeHandler)
$RecurseCheck.Add_Checked({ Reset-ScanResults })
$RecurseCheck.Add_Unchecked({ Reset-ScanResults })
$FolderBox.Add_TextChanged({ Reset-ScanResults })
$CustomBox.Add_TextChanged({ Reset-ScanResults })
$PermanentCheck.Add_Checked({ Update-DeleteButton })
$PermanentCheck.Add_Unchecked({ Update-DeleteButton })

$BrowseButton.Add_Click({
        try {
            $initial = $FolderBox.Text.Trim().Trim('"')
            if ('Microsoft.Win32.OpenFolderDialog' -as [type]) {
                $dialog = [Microsoft.Win32.OpenFolderDialog]::new()
                $dialog.Title = 'Select the folder to clean'
                if ($initial -and (Test-Path -LiteralPath $initial -PathType Container)) { $dialog.InitialDirectory = $initial }
                if ($dialog.ShowDialog($window)) { $FolderBox.Text = $dialog.FolderName }
            }
            else {
                Add-Type -AssemblyName System.Windows.Forms
                $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
                $dialog.Description = 'Select the folder to clean'
                if ($initial) { $dialog.SelectedPath = $initial }
                if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $FolderBox.Text = $dialog.SelectedPath }
            }
        }
        catch { Show-Message -Text $_.Exception.Message -Icon Error }
    })

$ScanButton.Add_Click({
        try {
            $folder = $FolderBox.Text.Trim().Trim('"')
            if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) {
                Show-Message -Text 'The folder does not exist. Choose an existing folder.' -Icon Warning
                return
            }
            $folder = (Resolve-Path -LiteralPath $folder).ProviderPath
            $reason = Test-ProtectedPath -Path $folder
            if ($reason) { Show-Message -Text $reason -Icon Warning; return }

            $exts = @(Get-SelectedExtensions)
            if ($exts.Count -eq 0) {
                Show-Message -Text 'Select at least one file type (or enter other extensions).' -Icon Information
                return
            }

            $exclude = @((Join-Path $folder $LogFileName))
            if ($PSCommandPath) { $exclude += $PSCommandPath }

            $state.ScanFolder = $folder
            $state.ScanRecurse = [bool]$RecurseCheck.IsChecked
            Clear-Results -Message 'Scanning...'
            $WorkProgress.Value = 0
            Start-Worker -Kind 'Scan' -Script $scanWork -Arguments @{
                Folder     = $folder
                Extensions = [string[]]$exts
                Recurse    = [bool]$RecurseCheck.IsChecked
                Exclude    = [string[]]$exclude
                AllFiles   = $false
            }
        }
        catch { Show-Message -Text $_.Exception.Message -Icon Error }
    })

function Save-CurrentSettings {
    $checked = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $checkBoxes.GetEnumerator()) {
        if ($entry.Value.IsChecked) { $checked.Add($entry.Key) }
    }
    Save-CleanerSettings -Settings ([ordered]@{
            Theme      = $state.Theme
            Folder     = $FolderBox.Text.Trim()
            Recurse    = [bool]$RecurseCheck.IsChecked
            Permanent  = [bool]$PermanentCheck.IsChecked
            Custom     = $CustomBox.Text.Trim()
            Extensions = $checked.ToArray()
        })
}

function Start-TempPreview {
    param([Parameter(Mandatory)][ValidateSet('UserTemp', 'WindowsTemp')][string]$Mode)
    try {
        if ($Mode -eq 'WindowsTemp' -and -not $state.IsElevated) {
            Show-Message -Text 'Cleaning Windows temp requires administrator rights. Use "Restart as administrator".' -Icon Warning
            return
        }
        $target = Get-TempTarget -Mode $Mode
        Clear-Results -Message 'Scanning...'
        $state.Mode = $Mode
        $state.ScanFolder = $target.Path
        $state.ScanRecurse = $true
        $WorkProgress.Value = 0
        Start-Worker -Kind 'Scan' -Script $scanWork -Arguments @{
            Folder     = $target.Path
            Extensions = [string[]]@()
            Recurse    = $true
            Exclude    = [string[]]@()
            AllFiles   = $true
        }
    }
    catch { Show-Message -Text $_.Exception.Message -Icon Error }
}

function Start-BinPreview {
    try {
        Clear-Results -Message 'Reading the Recycle Bin...'
        $state.Mode = 'RecycleBin'
        $state.ScanFolder = ''
        $WorkProgress.Value = 0
        Start-Worker -Kind 'BinScan' -Script $binScanWork -Arguments @{}
    }
    catch { Show-Message -Text $_.Exception.Message -Icon Error }
}

$UserTempButton.Add_Click({ Start-TempPreview -Mode 'UserTemp' })
$WindowsTempButton.Add_Click({ Start-TempPreview -Mode 'WindowsTemp' })
$BinButton.Add_Click({ Start-BinPreview })

$RestartAdminButton.Add_Click({
        try {
            if (-not $PSCommandPath) { throw 'The script must be run from a saved .ps1 file to restart elevated.' }
            Save-CurrentSettings
            $hostExe = (Get-Process -Id $PID).Path
            Start-Process -FilePath $hostExe -Verb RunAs -WindowStyle Hidden -ArgumentList @('-STA', '-NoProfile', '-File', ('"{0}"' -f $PSCommandPath))
            $window.Close()
        }
        catch { Show-Message -Text ('Could not restart as administrator: ' + $_.Exception.Message) -Icon Warning }
    })

$DeleteButton.Add_Click({
        try {
            $mode = $state.Mode
            if ($null -eq $state.Items -or $state.Items.Count -eq 0) { return }

            $total = [long]0
            foreach ($f in $state.Items) { $total += [long]$f.Length }

            if ($mode -eq 'RecycleBin') {
                $state.BinText = '({0} items, {1})' -f $state.Items.Count, (Format-Size $total)
                $binMessage = "Permanently remove all {0} items ({1}) from the Recycle Bin (all drives)?`n`nThis cannot be undone." -f $state.Items.Count, (Format-Size $total)
                $binAnswer = [System.Windows.MessageBox]::Show($window, $binMessage, 'Empty Recycle Bin',
                    [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning, [System.Windows.MessageBoxResult]::No)
                if ($binAnswer -ne [System.Windows.MessageBoxResult]::Yes) { return }
                $WorkProgress.Value = 0
                Start-Worker -Kind 'BinEmpty' -Script $binEmptyWork -Arguments @{}
                return
            }

            if ($mode -eq 'Types') {
                $permanent = [bool]$PermanentCheck.IsChecked
                $prune = ''
                if ($permanent) { $consequence = 'They will be PERMANENTLY deleted and cannot be recovered.' }
                else { $consequence = 'They will be moved to the Recycle Bin.' }
            }
            else {
                $permanent = $true
                $prune = $state.ScanFolder
                $consequence = 'They will be PERMANENTLY deleted (not sent to the Recycle Bin), and the subfolders are removed with them. Files in use are skipped, so their folders stay.'
            }
            $message = "{0} files ({1}) from:`n{2}`n`n{3}`n`nContinue?" -f $state.Items.Count, (Format-Size $total), $state.ScanFolder, $consequence

            $answer = [System.Windows.MessageBox]::Show($window, $message, 'Confirm clean-up',
                [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning, [System.Windows.MessageBoxResult]::No)
            if ($answer -ne [System.Windows.MessageBoxResult]::Yes) { return }

            $state.Permanent = $permanent
            $WorkProgress.Value = 0
            Start-Worker -Kind 'Delete' -Script $deleteWork -Arguments @{
                Files     = $state.Items.ToArray()
                Permanent = $permanent
                PruneRoot = $prune
            }
        }
        catch { Show-Message -Text $_.Exception.Message -Icon Error }
    })

$CancelButton.Add_Click({
        if ($state.Busy -and $state.Sync) {
            $state.Sync.Cancel = $true
            $StatusText.Text = 'Cancelling...'
        }
    })

$window.Add_Closing({
        # Stop any running work, then persist settings
        if ($state.Busy -and $state.Sync) {
            $state.Sync.Cancel = $true
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            while (-not $state.Sync.Finished -and $stopwatch.ElapsedMilliseconds -lt 3000) { Start-Sleep -Milliseconds 50 }
        }
        Save-CurrentSettings
    })

[void]$window.ShowDialog()