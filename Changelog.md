# Changelog

All notable changes to `Clean-Folder.ps1` are documented in this file.

The format is based on [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

When changing the script, update all three places together: this file, the `.VERSION` field in the
`PSScriptInfo` block, and `$ScriptVersion`.

## [Unreleased]

## [2.3.1] - 2026-10-13

### Fixed
- Temp clean-up now removes subfolders reliably. Read-only folders are no longer left behind, and junctions or symlinks inside the temp folder are removed as links (their targets are never followed or touched).
- The summary reports how many folders were removed and how many could not be removed. A folder stays when it still holds a file that is in use.

## [2.3.0] - 2026-10-13

### Added
- Office & Documents: `one` (OneNote), `vsdx` (Visio).
- Code & Misc: `msg` (Outlook message), alongside `eml`.
- `README.md` with an executive summary, usage examples and author information.

## [2.2.0] - 2026-10-12

### Added
- **System clean-up** row in the GUI with three buttons: **Clean user temp**, **Clean Windows temp** and **Empty Recycle Bin**. Each button loads a preview into the results grid first; the red button then asks for confirmation before anything is deleted.
- Temp clean-up removes everything that is not in use (no age filter), always permanently. Files in use are skipped (reported as skipped, not as errors), junctions and symlinks are not followed, and subfolders left empty are removed. The temp folder itself is never removed.
- **Clean Windows temp** (`C:\Windows\Temp`) is enabled only in an elevated session. Otherwise it is greyed out with an explanatory tooltip and a **Restart as administrator** button appears (settings are saved first).
- **Empty Recycle Bin** previews the bin contents (all drives, current user) and shows the item count and total size in the confirmation. Emptying cannot be cancelled once started.
- Command-line switches `-CleanUserTemp`, `-CleanWindowsTemp` and `-EmptyRecycleBin`. All support `-WhatIf` and `-Confirm` and can be combined with each other and with `-Category` / `-Extension`.
- `-CleanWindowsTemp` without elevation exits with code 3.
- System clean-up tasks are logged to `%APPDATA%\CleanFolder\clean-up.log`, not inside the folder being cleaned.

### Changed
- The delete button label and style follow the pending action (Move to Recycle Bin, Delete permanently, Delete user temp permanently, Delete Windows temp permanently, Empty Recycle Bin).
- The "nothing selected" error message now mentions the new switches.
- Default window height is 860 and the minimum is 720 to fit the new row.
- Internal: the command-line mode is split into functions.

## [2.1.2] - 2026-10-12

### Changed
- Extension checkboxes are sorted alphabetically within each category group. Short extensions (a-z) fill the three-column grid and long extensions (8+ characters) are sorted separately in the two-column grid below it. This affects the GUI only; the command line is unchanged.

## [2.1.1] - 2026-10-12

### Fixed
- Extension checkboxes now line up in aligned columns in every category group. Long extensions (8+ characters, such as `.msixbundle` and `.opdownload`) are listed after the short ones so they no longer push the other columns out of line.

## [2.1.0] - 2026-10-12

### Added
- Archives: `7z`, `rar`.
- Audio & Video: `flac`, `wav`, `m4a`, `wma`.
- Web: `css`, `js`, `php`.
- Installers & Packages: `msix`, `msixbundle`, `appx`, `appxbundle`, `msp`, `cab`.
- New **Temp & Partial Downloads** category (CLI: `-Category Temp`): `tmp`, `temp`, `crdownload`, `part`, `partial`, `download`, `opdownload`, `bak`, `old`.
- `-Version` switch prints the script version.
- Version shown in the window title and written to each `clean-up.log` entry.
- `PSScriptInfo` metadata block (`.VERSION`, `.GUID`) and this changelog.

### Notes
- `webp` remains under Images only. Extension checkboxes are keyed by extension, so an extension can belong to one group.

## [2.0.0] - 2026-10-12

### Added
- WPF GUI: dark and light themes with matching palettes, one group box per file category, a checkbox per extension, All/None per group, and a field for other extensions.
- Scan-then-delete workflow with a sortable preview grid, progress bar and Cancel. Work runs in a background runspace.
- Recursion option (`-Recurse` / "Include subfolders"). Junctions and symlinks are not followed.
- Recycle Bin by default, with `-Permanent` / "Delete permanently" to skip it.
- `-Category` and `-Extension` parameters, and `-NoGui` to force headless mode.
- Settings (theme, folder, options, ticked types) saved to `%APPDATA%\CleanFolder\settings.json`.
- Protected-folder guard: drive roots, Windows, Program Files, ProgramData and the bare user profile are refused.
- Extra types: `xlsx`, `xls`, `pptx`, `ppt`, `odt`, `rtf`, `gif`, `bmp`, `webp`, `htm`, `log`.

### Changed
- **Breaking:** running with no parameters now opens the GUI instead of cleaning immediately. Scheduled tasks must pass `-NoGui` with `-Category` or `-Extension`.
- **Breaking:** `-EverQuestLogs` now covers `.txt` and `.log` and no longer applies the full extension list.
- **Breaking:** files go to the Recycle Bin unless `-Permanent` is given.
- **Breaking:** no file types are selected by default; the fixed built-in list is replaced by explicit selection.
- Log entries now include mode, recursion, file count and failures.

## [1.0.0] - 2026-10-12

First versioned release: a corrected command-line version of the original script.

### Added
- `-WhatIf` and `-Confirm` support.
- Per-file error handling with a failure count in the summary.
- Self-protection: the script and `clean-up.log` are never deleted.

### Changed
- Default folder is built from `$env:USERPROFILE` instead of a hard-coded path.
- Sizes are shown in MB or GB as appropriate, and the log records files deleted and failures.

### Fixed
- The loop no longer aborts at the first pattern with no matching files.
- Reported sizes now count only files that were actually deleted.
- `-EverQuestLogs` no longer overrides an explicit `-Folder` or deletes non-log file types.
- Files are enumerated once rather than twice per pattern.

[Unreleased]: #unreleased
[2.3.1]: #231---2026-10-13
[2.3.0]: #230---2026-10-13
[2.2.0]: #220---2026-10-12
[2.1.2]: #212---2026-10-12
[2.1.1]: #211---2026-10-12
[2.1.0]: #210---2026-10-12
[2.0.0]: #200---2026-10-12
[1.0.0]: #100---2026-10-12