# Named folder colors. Mid-tone shades recolor the Win11 folder best; black and
# white are pulled in from the extremes so the folder's shading stays visible.
$script:WinDivColors = [ordered]@{
   'native'  = $null;   # keep the stock Windows folder color
   'red'     = '#EF4444';
   'rose'    = '#F43F5E';
   'orange'  = '#F97316';
   'amber'   = '#F59E0B';
   'yellow'  = '#EAB308';
   'lime'    = '#84CC16';
   'green'   = '#22C55E';
   'emerald' = '#10B981';
   'teal'    = '#14B8A6';
   'cyan'    = '#06B6D4';
   'sky'     = '#0EA5E9';
   'blue'    = '#3B82F6';
   'indigo'  = '#6366F1';
   'violet'  = '#8B5CF6';
   'purple'  = '#A855F7';
   'pink'    = '#EC4899';
   'brown'   = '#A16207';
   'gray'    = '#6B7280';
   'slate'   = '#475569';
   'black'   = '#3F3F46';
   'white'   = '#E5E7EB';
};

# Returns a normalized '#RRGGBB' string, or $null for 'native'.
function ConvertTo-WinDivHex {
   param (
      [Parameter(Mandatory = $true)]
      [string] $Color
   )

   $value = $Color.Trim();
   $key = $value.ToLowerInvariant();
   if ($script:WinDivColors.Contains($key)) {
      return $script:WinDivColors[$key];
   }

   if ($value -match '^#?([0-9A-Fa-f]{6})$') {
      return "#$($Matches[1].ToUpperInvariant())";
   }
   if ($value -match '^#?([0-9A-Fa-f])([0-9A-Fa-f])([0-9A-Fa-f])$') {
      return ("#{0}{0}{1}{1}{2}{2}" -f $Matches[1], $Matches[2], $Matches[3]).ToUpperInvariant();
   }

   # Fall back to .NET's known color names (e.g. 'CornflowerBlue')
   $known = [System.Drawing.Color]::FromName($value);
   if ($known.IsKnownColor) {
      return '#{0:X2}{1:X2}{2:X2}' -f $known.R, $known.G, $known.B;
   }

   throw "Unknown color '$Color'. Use a name from 'divs colors', or hex like '#3B82F6'.";
}

function ConvertTo-WinDivColor {
   param (
      [AllowNull()]
      [string] $Hex
   )

   if (-not $Hex) { return $null; }
   return [System.Drawing.ColorTranslator]::FromHtml($Hex);
}
