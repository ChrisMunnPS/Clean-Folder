<p align="center">
  <a href="https://github.com/ChrisMunnPS/Clean-Folder"><img alt="GitHub repository" src="https://img.shields.io/badge/GitHub-Repository-181717?logo=github&logoColor=white"></a>
  <a href="https://github.com/ChrisMunnPS/Clean-Folder/releases/latest"><img alt="Download" src="https://img.shields.io/badge/Download-Latest%20release-2EA44F?logo=github&logoColor=white"></a>
  <a href="CHANGELOG.md"><img alt="Changelog" src="https://img.shields.io/badge/Changelog-Keep%20a%20Changelog-E05735"></a>
  <a href="https://ChrisMunnPS.github.io"><img alt="Portfolio" src="https://img.shields.io/badge/Portfolio-ChrisMunnPS.github.io-8A2BE2"></a>
</p>

<p align="center">
  <img alt="Version" src="https://img.shields.io/github/v/tag/ChrisMunnPS/Clean-Folder?label=version&sort=semver">
  <img alt="PowerShell 5.1" src="https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white">
  <img alt="Windows 10 and 11" src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white">
  <a href="https://semver.org/spec/v2.0.0.html"><img alt="SemVer 2.0.0" src="https://img.shields.io/badge/SemVer-2.0.0-3F4551"></a>
  <a href="https://github.com/ChrisMunnPS/Clean-Folder/stargazers"><img alt="Stars" src="https://img.shields.io/github/stars/ChrisMunnPS/Clean-Folder?style=flat"></a>
</p>

# 🧹 Clean-Folder

## 📌 Executive Summary

**Clean-Folder** is a single-file PowerShell tool for Windows that reclaims disk space by removing the clutter *you* choose: old downloads by file type, user and Windows temp files, and the Recycle Bin. It has a modern dark/light WPF interface for hands-on use and a full command line for automation, both running the same engine.

- 🎯 **Targeted:** tick file types by category (Office, Images, Installers, Archives and more), optionally include subfolders.
- 👀 **Preview first:** every clean-up shows exactly what will go before anything is touched.
- 🛡️ **Safe by default:** files go to the Recycle Bin unless you ask for permanent deletion, and system folders are protected.
- ⌨️ **Automation-ready:** the same actions are available as switches, with `-WhatIf`, `-Confirm` and meaningful exit codes.
- 📦 **Zero dependencies:** one `.ps1` file, built for Windows PowerShell 5.1.

| | |
|---|---|
| **Platform** | Windows 10 / 11 |
| **Requires** | Windows PowerShell 5.1 (PowerShell 7 on Windows is expected to work). The GUI needs a desktop session |
| **Interfaces** | GUI (default) and command line |
| **Version** | Run `.\Clean-Folder.ps1 -Version`, or see the [changelog](CHANGELOG.md) |

---

## ✨ Features

- 🗂️ **Category checkboxes:** 11 groups with a checkbox per extension, plus *All* / *None* per group and a box for your own extensions.
- 🔁 **Recursion option:** include subfolders (junctions and symlinks are never followed).
- 🔍 **Scan, review, then clean:** a sortable preview grid shows name, folder, type and size.
- ♻️ **Recycle Bin by default,** with a clearly marked *Delete permanently* option.
- 🧼 **System clean-up:** user temp, Windows temp (when elevated) and Empty Recycle Bin, each with a preview.
- 🌗 **Dark and light themes** that follow Windows by default and remember your choice.
- ⏱️ **Responsive:** scanning and deleting run in the background with progress and Cancel.
- 💾 **Remembers your settings:** theme, folder, options and ticked types.
- 🔖 **Versioned:** [Semantic Versioning](https://semver.org/) with a [Keep a Changelog](https://keepachangelog.com/) history.

---

## 🚀 Getting Started

### Install

```powershell
git clone https://github.com/ChrisMunnPS/Clean-Folder.git
cd Clean-Folder
Unblock-File .\Clean-Folder.ps1   # only needed if the file was downloaded as a zip
```

You can also download just `Clean-Folder.ps1`; it has no other files to install.

### Run

```powershell
.\Clean-Folder.ps1                # opens the GUI
.\Clean-Folder.ps1 -Version       # prints the version
Get-Help .\Clean-Folder.ps1 -Full # built-in help and examples
```

If scripts are blocked on your machine, see [Troubleshooting](#-troubleshooting).

---

## 🖥️ Using the GUI

Running the script with no parameters opens the window.

1. 📁 **Choose a folder.** It defaults to your Downloads folder. Tick *Include subfolders* to recurse.
2. ☑️ **Tick file types.** Use the category group boxes, or type extra extensions such as `rtf, sqlite`.
3. 🔍 **Click Scan.** Matching files appear in the grid with a total count and size.
4. 👀 **Review the list.** Sort by any column. Changing a checkbox or the folder clears the preview so you never delete a stale list.
5. ♻️ **Choose how to clean up.** *Move to Recycle Bin* is the default. Tick *Delete permanently* to turn the button red and skip the bin.
6. ✅ **Confirm.** A dialog shows the file count, size and what will happen. Nothing is deleted until you click *Yes*.

### 💡 Example: clear out last month's installers and torrents

1. Folder: `C:\Users\you\Downloads`, tick *Include subfolders*.
2. Tick `.exe`, `.msi`, `.iso` in **Installers & Packages** and **All** in **Torrents & Usenet**.
3. Scan, glance at the list, click **Move to Recycle Bin**.
4. Changed your mind? Restore anything from the Recycle Bin.

---

## 🗂️ File Categories

Extensions are listed alphabetically in the GUI. Nothing is ticked on first run, so you opt in to each type.

| | Category | `-Category` | Extensions |
|---|---|---|---|
| 📄 | Office & Documents | `Office` | `.doc` `.docx` `.odt` `.one` `.pdf` `.ppt` `.pptx` `.rtf` `.vsdx` `.xls` `.xlsx` |
| 📝 | Text & Logs | `Text` | `.csv` `.json` `.log` `.md` `.txt` `.xml` |
| 🌐 | Web | `Web` | `.css` `.htm` `.html` `.js` `.php` |
| 🖼 | Images | `Images` | `.bmp` `.gif` `.jpeg` `.jpg` `.png` `.webp` |
| 🎵 | Audio & Video | `Media` | `.flac` `.m4a` `.mp3` `.mp4` `.wav` `.wma` |
| 📦 | Installers & Packages | `Installers` | `.appx` `.appxbundle` `.bin` `.cab` `.deb` `.exe` `.iso` `.msi` `.msix` `.msixbundle` `.msp` `.pkg` `.spk` |
| 🗃 | Archives | `Archives` | `.7z` `.rar` `.zip` |
| 📥 | Torrents & Usenet | `Torrents` | `.nzb` `.torrent` |
| 📚 | eBooks | `Ebooks` | `.epub` `.mobi` |
| 💻 | Code & Misc | `Code` | `.cs` `.eml` `.evtx` `.ics` `.msg` `.ps1` |
| 🗑 | Temp & Partial Downloads | `Temp` | `.bak` `.crdownload` `.download` `.old` `.opdownload` `.part` `.partial` `.temp` `.tmp` |

> 💡 Need something else? Type it into **Other extensions** in the GUI, or use `-Extension` on the command line.

---

## 🧰 System Clean-Up

A dedicated row of buttons handles common Windows housekeeping. Each button **loads a preview into the results grid first**; the red button then asks for confirmation.

| Button | What it does | Notes |
|---|---|---|
| 🗑️ **Clean user temp** | Deletes everything in your temp folder that is not in use | Permanent. Subfolders are cleared and removed too; locked files are skipped and keep their folders |
| 🪟 **Clean Windows temp** | Same for `C:\Windows\Temp` | Needs an elevated session. Otherwise greyed out, with a **Restart as administrator** button |
| ♻️ **Empty Recycle Bin** | Empties the bin for your account across all drives | Shows item count and size first. Cannot be undone or cancelled once started |

⚠️ There is no age filter: anything not in use is listed. Skim the preview on machines that are mid-update or mid-install.

---

## ⌨️ Command Line

Any of these parameters runs the tool headless: `-Folder`, `-Category`, `-Extension`, `-Recurse`, `-Permanent`, `-EverQuestLogs`, `-CleanUserTemp`, `-CleanWindowsTemp`, `-EmptyRecycleBin`, `-NoGui`, `-Version` or `-WhatIf`.

| Parameter | Description |
|---|---|
| `-Folder <path>` | Folder to clean. Defaults to Downloads |
| `-Category <names>` | One or more of `Office`, `Text`, `Web`, `Images`, `Media`, `Installers`, `Archives`, `Torrents`, `Ebooks`, `Code`, `Temp` |
| `-Extension <list>` | Extra extensions, with or without a leading dot (`pdf, .rtf`) |
| `-Recurse` | Include subfolders |
| `-Permanent` | Delete permanently instead of using the Recycle Bin |
| `-EverQuestLogs` | Shortcut for `.txt` and `.log` in `C:\everquest\logs` (unless `-Folder` is given) |
| `-CleanUserTemp` | Clean your temp folder (everything not in use) |
| `-CleanWindowsTemp` | Clean `C:\Windows\Temp` (requires an elevated session) |
| `-EmptyRecycleBin` | Permanently empty the Recycle Bin |
| `-NoGui` | Force headless mode |
| `-WhatIf` / `-Confirm` | Preview, or confirm each action |
| `-Version` | Print the version and exit |

### 🎬 Examples in action

Sample output below is illustrative; your paths and numbers will differ.

**1. Preview before deleting** with `-WhatIf`:

```powershell
.\Clean-Folder.ps1 -Category Torrents,Archives -Recurse -WhatIf
```

```text
Scanning 'C:\Users\you\Downloads' for: .torrent .nzb .zip .7z .rar (including subfolders)
What if: Performing the operation "Move to Recycle Bin" on target "C:\Users\you\Downloads\ubuntu.iso.torrent".
What if: Performing the operation "Move to Recycle Bin" on target "C:\Users\you\Downloads\old\project.zip".
...
48 matching files found. Nothing was deleted (WhatIf or declined).
```

**2. Clean specific types from a specific folder:**

```powershell
.\Clean-Folder.ps1 -Folder D:\Inbox -Extension pdf,docx
```

```text
Scanning 'D:\Inbox' for: .pdf .docx
Breakdown of deleted files:

Type  Files Size
----  ----- ----
.pdf     23 412.6 MB
.docx    11 38.2 MB

Files deleted: 34 | Total size: 450.8 MB | Failures: 0
```

**3. Permanent delete with no Recycle Bin, no prompts:**

```powershell
.\Clean-Folder.ps1 -Folder D:\Temp -Category Temp -Permanent
```

**4. Housekeeping: user temp and the Recycle Bin in one go:**

```powershell
.\Clean-Folder.ps1 -CleanUserTemp -EmptyRecycleBin
```

```text
Scanning user temp 'C:\Users\you\AppData\Local\Temp' (everything not in use)
user temp: 482 files deleted (96.4 MB), 17 skipped (in use or no access), 31 folders removed, 4 folders could not be removed (in use or not empty).
Recycle Bin emptied: 58 items (2.31 GB).
```

**5. Windows temp from a non-elevated session** is refused up front:

```powershell
.\Clean-Folder.ps1 -CleanWindowsTemp
```

```text
-CleanWindowsTemp requires an elevated (Run as administrator) PowerShell session.
```

**6. EverQuest log housekeeping:**

```powershell
.\Clean-Folder.ps1 -EverQuestLogs -Verbose
```

---

## 🕒 Scheduling

Running the script with **no parameters opens the GUI**, so scheduled tasks must always pass `-NoGui` (or any other parameter). In Task Scheduler, create an action like:

- **Program:** `powershell.exe`
- **Arguments:**

```text
-NoProfile -File "C:\Scripts\Clean-Folder.ps1" -NoGui -Folder "C:\Users\you\Downloads" -Category Torrents,Installers -Recurse
```

Run a `-WhatIf` version first and review the output before scheduling anything destructive.

---

## 🛡️ Safety Features

- 👀 **Preview before delete** in the GUI; `-WhatIf` and `-Confirm` on the command line.
- ♻️ **Recycle Bin by default;** permanent deletion is an explicit choice.
- 🚧 **Protected locations:** drive roots, network share roots, Windows, Program Files, ProgramData and your bare profile folder are refused.
- 🎯 **Fixed targets for system clean-up:** user temp and Windows temp are resolved by the tool, never typed in, so they cannot be redirected somewhere dangerous.
- 🔗 **Junctions and symlinks are not followed,** so recursion cannot wander outside the folder you chose.
- 🙈 **Self-protection:** the script and `clean-up.log` are never deleted.
- 🔒 **Locked files are skipped,** not forced; failures are counted and reported.
- 🔐 **Elevation is never assumed:** Windows temp is unavailable unless the session is elevated.

⚠️ Deleting files is destructive. Use at your own risk and review previews first.

---

## ⚙️ Settings, Logs & Files

| Item | Location |
|---|---|
| GUI settings (theme, folder, options, ticked types) | `%APPDATA%\CleanFolder\settings.json` |
| Log for file-type clean-ups | `clean-up.log` inside the cleaned folder |
| Log for temp and Recycle Bin tasks | `%APPDATA%\CleanFolder\clean-up.log` |

The command line does not read or write the GUI settings file.

---

## 🔢 Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success (including "nothing to clean") |
| `1` | Invalid input, such as a missing folder, a protected folder, no file types selected or a bad extension |
| `2` | Some files could not be deleted, or the Recycle Bin could not be emptied |
| `3` | `-CleanWindowsTemp` was used without an elevated session |

---

## 🔖 Versioning

This project follows [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html). Every change updates three places together: the `PSScriptInfo` `.VERSION`, the `$ScriptVersion` variable and [CHANGELOG.md](CHANGELOG.md) ([Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format). The version appears in the window title, the log lines and `-Version`.

---

## 🩺 Troubleshooting

| Problem | What to do |
|---|---|
| *"Running scripts is disabled on this system"* | Unblock the file with `Unblock-File .\Clean-Folder.ps1`, or set an execution policy that suits your environment, for example `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| **Clean Windows temp** is greyed out | Start the app elevated. Click **Restart as administrator**, or run PowerShell as administrator |
| A scheduled task opens a window and hangs | Add `-NoGui` and at least one of `-Category`, `-Extension` or the clean-up switches |
| Files did not go to the Recycle Bin | Windows deletes permanently on network shares, many removable drives and very large files, regardless of the checkbox |
| Some files were skipped | They were in use or access was denied. Close the owning program and run again |
| Nothing appears after Scan | No files matched the ticked types in that folder. Check the folder and *Include subfolders* |

---

## 👤 About

**Chris Munn**

- 📦 **Repository:** [https://github.com/ChrisMunnPS/Clean-Folder](https://github.com/ChrisMunnPS/Clean-Folder)
- 🌐 **Portfolio Page:** [https://ChrisMunnPS.github.io](https://ChrisMunnPS.github.io)
