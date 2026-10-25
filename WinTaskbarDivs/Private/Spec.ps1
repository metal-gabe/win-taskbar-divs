# Validates the user's look options and builds the IconSpec the renderer needs.
function New-WinDivSpec {
   param (
      [string] $Color = 'native',
      [string] $Icon,
      [string] $Text,
      [string] $Image,
      [ValidateSet('Center', 'Badge')]
      [string] $Placement = 'Center',
      [string] $IconColor,
      [switch] $Bar
   )

   if ($Bar) {
      $ignored = @(
         if ($Color -ne 'native') { '-Color' }
         if ($Icon) { '-Icon' }
         if ($Text) { '-Text' }
         if ($Image) { '-Image' }
         if ($Placement -ne 'Center') { '-Placement' }
         if ($IconColor) { '-IconColor' }
      );
      if ($ignored) {
         Write-Warning "-Bar draws only a white bar; ignoring $($ignored -join ', ').";
      }
      $spec = [WinTaskbarDivs.IconSpec]::new();
      $spec.Kind = 'Bar';
      return [pscustomobject]@{
         Spec         = $spec;
         ColorHex     = $null;
         IconColorHex = $null;
         OverlayType  = 'bar';
         OverlayValue = $null;
      };
   }

   $chosen = @(
      @{ Type = 'Icon'; Value = $Icon },
      @{ Type = 'Text'; Value = $Text },
      @{ Type = 'Image'; Value = $Image }
   ) | Where-Object { $_.Value };
   if (@($chosen).Count -ne 1) {
      throw 'Pick exactly one overlay: -Icon <name|U+XXXX>, -Text <1-3 chars>, or -Image <path>.';
   }
   $overlay = @($chosen)[0];

   $spec = [WinTaskbarDivs.IconSpec]::new();
   $spec.Kind = $overlay.Type;
   $spec.Placement = $Placement;

   switch ($overlay.Type) {
      'Icon' {
         $spec.Value = Resolve-WinDivIcon $Icon;
      }
      'Text' {
         $length = [System.Globalization.StringInfo]::new($Text.Trim()).LengthInTextElements;
         if ($length -lt 1 -or $length -gt 3) {
            throw "-Text must be 1 to 3 characters (got '$Text').";
         }
         $spec.Value = $Text.Trim();
      }
      'Image' {
         $resolved = Resolve-Path -LiteralPath $Image -ErrorAction SilentlyContinue;
         if (-not $resolved) { throw "Image not found: '$Image'."; }
         $ext = [System.IO.Path]::GetExtension($resolved.ProviderPath).ToLowerInvariant();
         if ($ext -notin '.png', '.ico', '.jpg', '.jpeg', '.bmp', '.gif') {
            throw "Unsupported image type '$ext'. Use .png, .ico, .jpg, .bmp or .gif.";
         }
         $overlay.Value = $resolved.ProviderPath;
         $spec.Value = $resolved.ProviderPath;
      }
   }

   $colorHex = ConvertTo-WinDivHex $Color;
   $spec.FolderColor = ConvertTo-WinDivColor $colorHex;

   $iconHex = $null;
   if ($IconColor) {
      $iconHex = ConvertTo-WinDivHex $IconColor;
      if (-not $iconHex) { throw "-IconColor can't be 'native'."; }
      $spec.OverlayColor = ConvertTo-WinDivColor $iconHex;
   }

   [pscustomobject]@{
      Spec         = $spec;
      ColorHex     = $colorHex;
      IconColorHex = $iconHex;
      OverlayType  = $overlay.Type.ToLowerInvariant();
      OverlayValue = $overlay.Value;
   };
}

# Renders every icon size, hands the bitmaps to $Action, then disposes them.
function Invoke-WinDivRender {
   param (
      [Parameter(Mandatory = $true)]
      [WinTaskbarDivs.IconSpec] $Spec,

      [Parameter(Mandatory = $true)]
      [scriptblock] $Action
   )

   $images = [WinTaskbarDivs.IconRenderer]::RenderAll($Spec);
   try {
      & $Action $images;
   } finally {
      foreach ($img in $images) { $img.Dispose(); }
   }
}
