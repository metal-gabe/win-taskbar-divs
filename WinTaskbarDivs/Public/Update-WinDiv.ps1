function Update-WinDiv {
   <#
   .SYNOPSIS
   Rebuilds dividers from their saved settings, picking up renderer changes.

   .DESCRIPTION
   Each divider is re-created with -Force, so it gets a new exe name and Explorer
   shows the new icon instead of a cached one. Pinned dividers have to be unpinned
   and pinned again, because the old pin points at the replaced exe.

   .EXAMPLE
   Update-WinDiv

   .EXAMPLE
   Update-WinDiv all

   .EXAMPLE
   Update-WinDiv dev-*
   #>
   [CmdletBinding(SupportsShouldProcess = $true)]
   param (
      [Parameter(Position = 0)]
      [string] $Id = '*'
   )

   if ($Id -eq 'all') { $Id = '*'; }

   $targets = @(Get-WinDiv -Id $Id);
   if (-not $targets) {
      if ([WildcardPattern]::ContainsWildcardCharacters($Id)) {
         Write-Host "No dividers match '$Id'." -ForegroundColor DarkGray;
      } else {
         Write-Error "No divider with id '$Id'. Run 'divs list' to see them.";
      }
      return;
   }

   $manifests = @(Read-WinDivManifests -Root (Get-WinDivRoot));
   $repin = @();
   foreach ($div in $targets) {
      if (-not $PSCmdlet.ShouldProcess($div.Path, 'Rebuild taskbar divider')) { continue; }

      $m = $manifests | Where-Object id -eq $div.Id | Select-Object -First 1;
      if ($m.overlay.type -eq 'bar') {
         $look = @{ Bar = $true };
      } else {
         $look = @{ $m.overlay.type = $m.overlay.value; Color = $m.color; Placement = $m.placement };
         if ($m.iconColor) { $look.IconColor = $m.iconColor; }
      }

      try {
         # New-WinDiv's "Created ..." messages don't fit a rebuild; report our own.
         New-WinDiv -Id $m.id -Tooltip $m.tooltip @look -NoOpen -Force -ErrorAction Stop 6>$null;
         Write-Host "Rebuilt divider '$($m.id)'." -ForegroundColor Green;
         if ($div.Pinned) { $repin += $m.id; }
      } catch {
         Write-Error "Couldn't rebuild '$($m.id)': $_";
      }
   }

   if ($repin) {
      Write-Warning "Still pinned to the old version: $($repin -join ', '). Unpin each, then pin its new shortcut ('divs open <id>').";
   }
}
