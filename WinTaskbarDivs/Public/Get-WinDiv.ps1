function Get-WinDiv {
   <#
   .SYNOPSIS
   Lists the taskbar dividers that have been created (wildcards allowed in -Id).
   #>
   [CmdletBinding()]
   param (
      [Parameter(Position = 0)]
      [string] $Id = '*'
   )

   $root = Get-WinDivRoot;
   $pinned = @(Get-WinDivPinnedTargets);

   foreach ($m in Read-WinDivManifests -Root $root) {
      if ($m.id -notlike $Id) { continue; }

      $isPinned = [bool]($pinned | Where-Object {
            $_.Target -and $_.Target.StartsWith("$($m.Path)\", [System.StringComparison]::OrdinalIgnoreCase)
         });

      $overlayValue = $m.overlay.value;
      if ($m.overlay.type -eq 'image') { $overlayValue = Split-Path $overlayValue -Leaf; }

      [pscustomobject]@{
         PSTypeName = 'WinTaskbarDivs.Divider';
         Id         = $m.id;
         Color      = $m.color;
         Overlay    = "$($m.overlay.type): $overlayValue";
         Placement  = $m.placement;
         Tooltip    = $m.tooltip;
         Pinned     = $isPinned;
         Version    = $m.version;
         Path       = $m.Path;
         Exe        = Join-Path $m.Path $m.exe;
         Link       = Join-Path $m.Path "$($m.linkName).lnk";
         Created    = $m.created;
      };
   }
}
