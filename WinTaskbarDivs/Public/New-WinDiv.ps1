function New-WinDiv {
   <#
   .SYNOPSIS
   Creates a taskbar divider pseudo-app: a recolored folder icon with an overlay,
   or (with -Bar) a plain white vertical bar.

   .EXAMPLE
   New-WinDiv -Color blue -Icon code -Tooltip 'Dev tools'

   .EXAMPLE
   New-WinDiv -Color '#E11D48' -Text WK

   .EXAMPLE
   New-WinDiv -Bar -Tooltip 'Work'
   #>
   [CmdletBinding(SupportsShouldProcess = $true)]
   param (
      [string] $Color = 'native',
      [string] $Icon,
      [string] $Text,
      [string] $Image,

      # Hover text. Omitted: the icon name for -Icon, the id for -Bar, otherwise
      # none. Pass '' for no visible tooltip.
      [AllowEmptyString()]
      [string] $Tooltip = '',

      [ValidateSet('Center', 'Badge')]
      [string] $Placement = 'Center',

      [string] $IconColor,

      # Just a white vertical bar; -Color, -Icon, -Text, -Image, -Placement and
      # -IconColor are ignored.
      [switch] $Bar,

      # Folder/exe name; defaults to a slug of the tooltip, or div-N (bar-N with -Bar).
      [string] $Id,

      # Don't open Explorer at the new shortcut afterwards.
      [switch] $NoOpen,

      # Replace an existing divider with the same id.
      [switch] $Force
   )

   $look = New-WinDivSpec -Color $Color -Icon $Icon -Text $Text -Image $Image -Placement $Placement -IconColor $IconColor -Bar:$Bar;

   $root = Get-WinDivRoot;
   Assert-WinDivWritable $root;
   $existing = @(Read-WinDivManifests -Root $root);

   if (-not $Id) {
      $Id = ConvertTo-WinDivSlug $Tooltip;
      if (-not $Id) {
         $prefix = if ($Bar) { 'bar' } else { 'div' };
         $n = 1;
         while (Test-Path -LiteralPath (Join-Path $root "$prefix-$n")) { $n++; }
         $Id = "$prefix-$n";
      }
   }
   $Id = $Id.ToLowerInvariant();
   if (-not (Test-WinDivId $Id)) {
      throw "Invalid id '$Id'. Use 1-40 lowercase letters, digits or dashes, starting with a letter or digit ('all' is reserved).";
   }

   # Default hover text, set after the id so it doesn't change the id: a bar shows
   # its id, an icon divider its icon name. An explicit -Tooltip '' means none.
   if (-not $PSBoundParameters.ContainsKey('Tooltip')) {
      if ($Bar) { $Tooltip = $Id; } elseif ($Icon) { $Tooltip = $Icon; }
   }

   $dir = Join-Path $root $Id;
   $version = 1;
   if (Test-Path -LiteralPath $dir) {
      if (-not $Force) {
         throw "Divider '$Id' already exists. Use -Force to replace it, or pick another -Id.";
      }
      $old = $existing | Where-Object { $_.id -eq $Id } | Select-Object -First 1;
      if ($old -and $old.version) { $version = [int]$old.version + 1; }
   }

   if (-not $PSCmdlet.ShouldProcess($dir, 'Create taskbar divider')) { return; }

   if (Test-Path -LiteralPath $dir) {
      Remove-Item -LiteralPath $dir -Recurse -Force;
   }
   New-Item -ItemType Directory -Path $dir | Out-Null;

   try {
      $icoPath = Join-Path $dir 'icon.ico';
      Invoke-WinDivRender -Spec $look.Spec -Action {
         param ($images)
         [WinTaskbarDivs.IconRenderer]::WriteIco($icoPath, $images);
      };

      # A new exe name on each re-create sidesteps Explorer's icon cache.
      $exeName = if ($version -gt 1) { "$Id-v$version.exe" } else { "$Id.exe" };
      $exePath = Join-Path $dir $exeName;
      Build-WinDivStub -OutFile $exePath -IconFile $icoPath -Title $Tooltip;

      $linkName = Get-WinDivLinkName -Tooltip $Tooltip -Root $root -Id $Id;
      $linkPath = Join-Path $dir "$linkName.lnk";
      New-WinDivLink -Path $linkPath -Target $exePath -Description $Tooltip -AppId "$script:WinDivAppIdPrefix$Id";

      $manifest = [ordered]@{
         id        = $Id;
         version   = $version;
         color     = if ($Bar) { $null } elseif ($look.ColorHex) { $look.ColorHex } else { 'native' };
         overlay   = [ordered]@{ type = $look.OverlayType; value = $look.OverlayValue };
         placement = if ($Bar) { $null } else { $Placement.ToLowerInvariant() };
         iconColor = $look.IconColorHex;
         tooltip   = $Tooltip;
         exe       = $exeName;
         linkName  = $linkName;
         created   = (Get-Date).ToString('o');
      };
      $manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $dir $script:WinDivManifestName) -Encoding utf8;
   } catch {
      # Don't leave a half-built divider behind
      Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue;
      throw;
   }

   if (-not $NoOpen) {
      Start-Process explorer.exe -ArgumentList "/select,`"$linkPath`"";
   }
   Write-Host "Created divider '$Id'. To pin it: right-click the shortcut > Show more options > Pin to taskbar." -ForegroundColor Green;
   if ($version -gt 1) {
      Write-Host "If the old version is pinned, unpin it first; it points at the replaced exe." -ForegroundColor Yellow;
   }

   Get-WinDiv -Id $Id;
}
