$script:WinDivHelp = @'

  divs - taskbar divider factory

  USAGE
    divs new      [-Color <c>] (-Icon <i> | -Text <t> | -Image <path>) [-Tooltip <text>]
                  [-Placement Center|Badge] [-IconColor <c>] [-Id <id>] [-NoOpen] [-Force]
    divs preview  [-Color <c>] (-Icon <i> | -Text <t> | -Image <path>) [-Placement ...] [-IconColor <c>]
    divs list     [<id>]
    divs remove   <id>
    divs open     [<id>]
    divs icons    [-Show [-Color <c>]]
    divs colors
    divs help

  OPTIONS
    -Color      Folder color: a name from 'divs colors', or hex (#3B82F6). Default: native.
    -Icon       Icon name from 'divs icons', or a Segoe Fluent Icons codepoint (U+E943).
    -Text       1-3 characters, e.g. WK or 01.
    -Image      A .png / .ico / .jpg to put on the folder.
    -Tooltip    Hover text. Leave it out for no tooltip.
    -Placement  Center (default) or Badge (small circle, bottom-right).
    -IconColor  Overlay color. Default: picked automatically for contrast.
    -Id         Folder/exe name. Default: from the tooltip, or div-N.
    -NoOpen     Don't open Explorer at the new shortcut.
    -Force      Replace an existing divider with the same id.
    -Show       (icons) Render every icon on a folder into an image and open it.
                Terminals can't draw these icons correctly, so use this to browse them.

  EXAMPLES
    divs new -Color blue -Icon code -Tooltip "Dev tools"
    divs new -Color "#E11D48" -Text WK
    divs new -Color teal -Image C:\pics\logo.png -Placement Badge
    divs preview -Color purple -Icon music

  Dividers live in C:\Program Files\WinTaskbarDivs\<id>\. Pin one by right-clicking
  its shortcut > Show more options > Pin to taskbar (Windows blocks pinning from scripts).

'@;

function divs {
   [CmdletBinding(SupportsShouldProcess = $true)]
   param (
      [Parameter(Position = 0)]
      [ValidateSet('new', 'preview', 'list', 'remove', 'open', 'icons', 'colors', 'help')]
      [string] $Action = 'help',

      [Parameter(Position = 1)]
      [string] $Id,

      [string] $Color,
      [string] $Icon,
      [string] $Text,
      [string] $Image,
      [AllowEmptyString()]
      [string] $Tooltip,
      [ValidateSet('Center', 'Badge')]
      [string] $Placement,
      [string] $IconColor,
      [string] $OutFile,
      [switch] $NoOpen,
      [switch] $Show,
      [switch] $Force
   )

   # Forward only the parameters the target command accepts; flag anything dropped.
   $bound = $PSBoundParameters;
   $forward = {
      param ([string] $Command)
      $target = (Get-Command $Command).Parameters;
      $splat = @{};
      foreach ($key in $bound.Keys) {
         if ($key -eq 'Action') { continue; }
         if ($target.ContainsKey($key)) {
            $splat[$key] = $bound[$key];
         } else {
            Write-Warning "-$key doesn't apply to 'divs $Action'; ignoring it.";
         }
      }
      $splat;
   };

   switch ($Action) {
      'new' {
         $splat = & $forward 'New-WinDiv';
         New-WinDiv @splat;
      }
      'preview' {
         $splat = & $forward 'Show-WinDivPreview';
         Show-WinDivPreview @splat;
      }
      'list' {
         $splat = & $forward 'Get-WinDiv';
         $found = @(Get-WinDiv @splat);
         if (-not $found) {
            Write-Host "No dividers yet. Create one with: divs new -Color blue -Icon code -Tooltip Dev" -ForegroundColor DarkGray;
         }
         $found;
      }
      'remove' {
         if (-not $Id) { throw "Usage: divs remove <id>   (see 'divs list')"; }
         $splat = & $forward 'Remove-WinDiv';
         Remove-WinDiv @splat;
      }
      'open' {
         $splat = & $forward 'Open-WinDiv';
         Open-WinDiv @splat;
      }
      'icons' {
         $splat = & $forward 'Get-WinDivIcon';
         Get-WinDivIcon @splat;
         if (-not $Show) {
            Write-Host "Terminal fonts can't draw these icons correctly. To see them: divs icons -Show [-Color blue]" -ForegroundColor DarkGray;
         }
      }
      'colors' { Get-WinDivColor; }
      'help' { Write-Host $script:WinDivHelp; }
   }
}
