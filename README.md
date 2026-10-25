# WinTaskbarDivs

Windows 11 won't pin folders to the taskbar. `divs` makes small do-nothing "apps" that look like standard Windows folders, recolored and with an icon, text or image on top, so you can pin them as visual dividers between groups of apps.

![examples](docs/examples.png)

Each divider is:

- a tiny exe (`Main()` returns immediately, no window) with the icon embedded, so clicking it on the taskbar does nothing
- a shortcut (`.lnk`) whose name is the hover text, with its own AppUserModelID so dividers never merge on the taskbar

Both live in `C:\Program Files\WinTaskbarDivs\<id>\`.

## Setup

Requires PowerShell 7.2+ on Windows 11. The C# compiler it uses (`csc.exe`, .NET Framework 4.x) ships with Windows.

```powershell
.\install.ps1
```

This does two things:

1. It grants your user write access to `C:\Program Files\WinTaskbarDivs`. This is the only UAC prompt you'll see.
2. It links the module into `Documents\PowerShell\Modules`, so `divs` loads automatically in every session.

To undo both, run `.\install.ps1 -Uninstall`.

## Usage

```powershell
divs new -Color blue -Icon code -Tooltip "Dev tools"
divs new -Color "#E11D48" -Text WK         # no -Tooltip = no hover text
divs new -Color teal -Image C:\pics\logo.png -Placement Badge
divs preview -Color purple -Icon music     # PNG preview, creates nothing
divs list
divs remove dev-tools
divs open [<id>]
divs icons                                 # icon names (Tab-completes too)
divs icons -Show -Color blue               # picture of every icon on a folder
divs colors                                # named colors (Tab-completes too)
divs help
```

| Option       | Meaning                                                                          |
| ------------ | -------------------------------------------------------------------------------- |
| `-Color`     | Folder color: a name (`divs colors`) or hex. Default `native` (stock yellow).    |
| `-Icon`      | A name from `divs icons`, or any Segoe Fluent Icons codepoint (`U+E943`).        |
| `-Text`      | 1–3 characters.                                                                  |
| `-Image`     | `.png`, `.ico`, `.jpg`, `.bmp` or `.gif`.                                        |
| `-Tooltip`   | Hover text. If you leave it out, there's no hover text.                          |
| `-Placement` | `Center` (default) or `Badge` (circle at the bottom-right).                      |
| `-IconColor` | Overlay color. Default: chosen automatically for contrast.                       |
| `-Id`        | Folder/exe name. Default: made from the tooltip, or `div-N`.                     |
| `-NoOpen`    | Don't open Explorer afterwards.                                                  |
| `-Force`     | Replace an existing divider with the same id.                                    |

You need exactly one of `-Icon`, `-Text` or `-Image`. The underlying commands (`New-WinDiv`, `Get-WinDiv`, `Remove-WinDiv`, `Show-WinDivPreview`, …) are exported too, for scripting.

### Pinning

Windows blocks pinning from scripts, so `divs new` opens Explorer with the new shortcut selected. Right-click it, then **Show more options**, then **Pin to taskbar**. Drag the pin to wherever you want the divider.

### Notes

- **No tooltip.** A file name can't be empty, so a divider with no tooltip gets a name made of invisible `U+3164` characters.
- **Name clashes.** When two dividers would have the same shortcut name, invisible characters are appended so their pins don't clash.
- **Forbidden characters.** Tooltip characters that Windows forbids in file names (`: / \ ? * " < > |`) are replaced with look-alikes.
- **Restyling.** `-Force` builds a new exe name, which gets around Explorer's icon cache. Unpin the old version, then pin the new one.
- **Removing.** `divs remove` can't unpin anything. It warns you when the divider is still pinned.
- **Icons in the terminal.** `divs icons` lists names only. The icons sit in Unicode's Private Use Area, where terminal fonts such as Nerd Fonts put their own unrelated symbols, so a terminal can't draw them reliably. Use `divs icons -Show` to see them.
- **Helper DLL cache.** The C# helper (`Native.cs`) is compiled once into `%LOCALAPPDATA%\WinTaskbarDivs` and loaded from there. Loading it straight from memory sometimes gets blocked by Defender. It recompiles by itself whenever `Native.cs` changes.
- **Testing elsewhere.** Set `$env:WINTASKBARDIVS_ROOT` to build dividers in another folder.
