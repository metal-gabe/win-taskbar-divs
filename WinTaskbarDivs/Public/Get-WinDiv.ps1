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

      $overlay = switch ($m.overlay.type) {
         'bar' { 'bar' }
         'image' { "image: $(Split-Path $m.overlay.value -Leaf)" }
         default { "$($m.overlay.type): $($m.overlay.value)" }
      };

      [pscustomobject]@{
         PSTypeName = 'WinTaskbarDivs.Divider';
         Id         = $m.id;
         Color      = $m.color;
         Overlay    = $overlay;
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
