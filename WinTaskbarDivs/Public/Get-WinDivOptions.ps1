function Get-WinDivIcon {
   <#
   .SYNOPSIS
   Lists the named icons usable with -Icon. -Show renders them to an image.

   .DESCRIPTION
   The icons live in the Unicode Private Use Area, which terminal fonts (e.g.
   Nerd Fonts) fill with their own unrelated symbols, so a terminal can't draw
   them reliably. -Show renders each icon on a divider folder into a PNG instead.
   #>
   [CmdletBinding()]
   param (
      # Render every icon on a folder into a PNG sheet and open it.
      [switch] $Show,

      # Folder color for the -Show sheet.
      [string] $Color = 'native',

      [string] $OutFile,

      # With -Show: write the PNG but don't open it.
      [switch] $NoOpen
   )

   if (-not $Show) {
      foreach ($name in $script:WinDivIcons.Keys) {
         [pscustomobject]@{
            Name      = $name;
            Codepoint = 'U+{0:X4}' -f $script:WinDivIcons[$name];
         };
      }
      return;
   }

   $folderColor = ConvertTo-WinDivColor (ConvertTo-WinDivHex $Color);
   if (-not $OutFile) {
      $OutFile = Join-Path ([System.IO.Path]::GetTempPath()) "divs-icons-$($Color.TrimStart('#').ToLowerInvariant()).png";
   }
   $OutFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutFile);

   $names = @($script:WinDivIcons.Keys);
   $cols = 8;
   $cellW = 120;
   $cellH = 112;
   $iconSize = 64;
   $rows = [math]::Ceiling($names.Count / $cols);

   $sheet = [System.Drawing.Bitmap]::new($cols * $cellW, $rows * $cellH);
   $g = [System.Drawing.Graphics]::FromImage($sheet);
   $nameFont = [System.Drawing.Font]::new('Segoe UI', 10);
   $codeFont = [System.Drawing.Font]::new('Segoe UI', 8);
   $center = [System.Drawing.StringFormat]::new();
   $center.Alignment = [System.Drawing.StringAlignment]::Center;
   try {
      $g.Clear([System.Drawing.Color]::FromArgb(243, 243, 243));
      $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit;

      for ($i = 0; $i -lt $names.Count; $i++) {
         $x = ($i % $cols) * $cellW;
         $y = [math]::Floor($i / $cols) * $cellH;

         $spec = [WinTaskbarDivs.IconSpec]::new();
         $spec.Kind = 'Icon';
         $spec.Value = [string][char]$script:WinDivIcons[$names[$i]];
         $spec.FolderColor = $folderColor;
         $img = [WinTaskbarDivs.IconRenderer]::Render($spec, $iconSize);
         try {
            $g.DrawImageUnscaled($img, $x + ($cellW - $iconSize) / 2, $y + 6);
         } finally {
            $img.Dispose();
         }

         $text = [System.Drawing.RectangleF]::new($x, $y + $iconSize + 10, $cellW, 18);
         $g.DrawString($names[$i], $nameFont, [System.Drawing.Brushes]::Black, $text, $center);
         $text.Y += 17;
         $g.DrawString(('U+{0:X4}' -f $script:WinDivIcons[$names[$i]]), $codeFont, [System.Drawing.Brushes]::Gray, $text, $center);
      }
      $sheet.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png);
   } finally {
      $center.Dispose();
      $codeFont.Dispose();
      $nameFont.Dispose();
      $g.Dispose();
      $sheet.Dispose();
   }

   if (-not $NoOpen) { Invoke-Item -LiteralPath $OutFile; }
   Get-Item -LiteralPath $OutFile;
}

function Get-WinDivColor {
   <#
   .SYNOPSIS
   Lists the named colors usable with -Color and -IconColor.
   #>
   $esc = [char]27;
   foreach ($name in $script:WinDivColors.Keys) {
      $hex = $script:WinDivColors[$name];
      $swatch = '';
      if ($hex) {
         $c = [System.Drawing.ColorTranslator]::FromHtml($hex);
         $swatch = "$esc[48;2;$($c.R);$($c.G);$($c.B)m      $esc[0m";
      }
      [pscustomobject]@{
         Name   = $name;
         Hex    = if ($hex) { $hex } else { '(stock folder)' };
         Swatch = $swatch;
      };
   }
}
