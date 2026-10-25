function Open-WinDiv {
   <#
   .SYNOPSIS
   Opens Explorer at the dividers folder, or with a divider's shortcut selected.
   #>
   [CmdletBinding()]
   param (
      [Parameter(Position = 0)]
      [string] $Id
   )

   if (-not $Id) {
      Start-Process explorer.exe -ArgumentList "`"$(Get-WinDivRoot)`"";
      return;
   }

   $div = Get-WinDiv -Id $Id | Where-Object Id -eq $Id;
   if (-not $div) { throw "No divider with id '$Id'. Run 'divs list' to see them."; }
   Start-Process explorer.exe -ArgumentList "/select,`"$($div.Link)`"";
}
