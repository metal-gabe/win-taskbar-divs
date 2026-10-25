function Remove-WinDiv {
   <#
   .SYNOPSIS
   Deletes a taskbar divider ('all' deletes every one). A pinned copy has to be unpinned by hand.
   #>
   [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
   param (
      [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
      [string[]] $Id,

      # Skip the confirmation prompt for 'all'.
      [switch] $Force
   )

   process {
      foreach ($one in $Id) {
         if ($one -eq 'all') {
            $targets = @(Get-WinDiv);
            if (-not $targets) {
               Write-Host "No dividers to remove." -ForegroundColor DarkGray;
               continue;
            }
            $question = "Delete all $($targets.Count) dividers ($($targets.Id -join ', '))?";
            if (-not ($Force -or $WhatIfPreference)) {
               try {
                  $confirmed = $PSCmdlet.ShouldContinue($question, 'Remove all dividers');
               } catch {
                  throw "Can't ask for confirmation here. Use -Force to remove all dividers.";
               }
               if (-not $confirmed) { continue; }
            }
         } else {
            $targets = @(Get-WinDiv -Id $one | Where-Object Id -eq $one);
            if (-not $targets) {
               Write-Error "No divider with id '$one'. Run 'divs list' to see them.";
               continue;
            }
         }

         foreach ($div in $targets) {
            if ($PSCmdlet.ShouldProcess($div.Path, 'Delete taskbar divider')) {
               Remove-Item -LiteralPath $div.Path -Recurse -Force;
               Write-Host "Removed divider '$($div.Id)'." -ForegroundColor Green;
               if ($div.Pinned) {
                  Write-Warning "'$($div.Id)' is still pinned. Right-click it on the taskbar > Unpin from taskbar.";
               }
            }
         }
      }
   }
}
