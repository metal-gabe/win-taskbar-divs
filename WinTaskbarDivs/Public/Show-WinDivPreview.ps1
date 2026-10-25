function Show-WinDivPreview {
   <#
   .SYNOPSIS
   Renders a divider icon to a PNG preview sheet without creating anything.

   .DESCRIPTION
   Top row: every icon size at 1:1. Bottom row: the taskbar sizes (24/32/40px)
   magnified 4x. Left half is on a light background, right half on dark.
   #>
   [CmdletBinding()]
   param (
      [string] $Color = 'native',
      [string] $Icon,
      [string] $Text,
      [string] $Image,

      [ValidateSet('Center', 'Badge')]
      [string] $Placement = 'Center',

      [string] $IconColor,

      [string] $OutFile,

      # Write the PNG but don't open it.
      [switch] $NoOpen
   )

   $look = New-WinDivSpec -Color $Color -Icon $Icon -Text $Text -Image $Image -Placement $Placement -IconColor $IconColor;

   if (-not $OutFile) {
      $OutFile = Join-Path ([System.IO.Path]::GetTempPath()) "divs-preview-$(Get-Date -Format 'yyyyMMdd-HHmmss').png";
   }
   $OutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile);

   Invoke-WinDivRender -Spec $look.Spec -Action {
      param ($images)
      [WinTaskbarDivs.IconRenderer]::SavePreview($OutFile, $images);
   };

   if (-not $NoOpen) { Invoke-Item -LiteralPath $OutFile; }
   Get-Item -LiteralPath $OutFile;
}
