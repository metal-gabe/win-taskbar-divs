function Remove-WinDiv {
   <#
   .SYNOPSIS
   Deletes a taskbar divider. A pinned copy has to be unpinned by hand.
   #>
   [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
   param (
      [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
      [string[]] $Id
   )

   process {
      foreach ($one in $Id) {
         $div = Get-WinDiv -Id $one | Where-Object Id -eq $one;
         if (-not $div) {
            Write-Error "No divider with id '$one'. Run 'divs list' to see them.";
            continue;
         }

         if ($PSCmdlet.ShouldProcess($div.Path, 'Delete taskbar divider')) {
            Remove-Item -LiteralPath $div.Path -Recurse -Force;
            Write-Host "Removed divider '$one'." -ForegroundColor Green;
            if ($div.Pinned) {
               Write-Warning "'$one' is still pinned. Right-click it on the taskbar > Unpin from taskbar.";
            }
         }
      }
   }
}
