# The pinned item's hover text is the .lnk's file name, so the name *is* the tooltip.
# With no tooltip, the name is made of U+3164 (Hangul Filler), which renders blank.
$script:WinDivBlank = [string][char]0x3164;
$script:WinDivZeroWidth = [string][char]0x200B;

# Look-alikes for characters Windows forbids in file names, so tooltips can contain them.
$script:WinDivNameSubstitutes = @{
   [char]':'  = [char]0x2236;
   [char]'/'  = [char]0x2215;
   [char]'\'  = [char]0x29F5;
   [char]'?'  = [char]0xFF1F;
   [char]'*'  = [char]0x2217;
   [char]'"'  = [char]0x201D;
   [char]'<'  = [char]0x2039;
   [char]'>'  = [char]0x203A;
   [char]'|'  = [char]0x01C0;
};

function ConvertTo-WinDivFileName {
   param (
      [Parameter(Mandatory = $true)]
      [string] $Text
   )

   $sb = [System.Text.StringBuilder]::new();
   foreach ($ch in $Text.ToCharArray()) {
      if ($script:WinDivNameSubstitutes.ContainsKey($ch)) {
         [void]$sb.Append($script:WinDivNameSubstitutes[$ch]);
      } elseif ([char]::IsControl($ch)) {
         [void]$sb.Append(' ');
      } else {
         [void]$sb.Append($ch);
      }
   }
   # Windows strips trailing dots and spaces from file names
   return $sb.ToString().TrimEnd('.', ' ');
}

# Picks a .lnk base name that collides with neither another divider's link nor an
# existing taskbar pin (pinning copies the .lnk, and a clash would add " (2)").
# Clashes are broken with invisible characters so the visible text is unchanged.
function Get-WinDivLinkName {
   param (
      [AllowEmptyString()]
      [string] $Tooltip,

      [Parameter(Mandatory = $true)]
      [string] $Root,

      [Parameter(Mandatory = $true)]
      [string] $Id
   )

   $taken = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase);
   $ownDir = Join-Path $Root $Id;

   foreach ($m in Read-WinDivManifests -Root $Root) {
      if ($m.id -ne $Id -and $m.linkName) { [void]$taken.Add($m.linkName); }
   }
   foreach ($pin in Get-WinDivPinnedTargets) {
      # this divider's own old pin (when re-creating with -Force) doesn't count
      if ($pin.Target -and $pin.Target.StartsWith("$ownDir\", [System.StringComparison]::OrdinalIgnoreCase)) { continue; }
      [void]$taken.Add($pin.Name);
   }

   if ($Tooltip) {
      $name = ConvertTo-WinDivFileName $Tooltip;
      if (-not $name) { $name = $script:WinDivBlank; }
      $pad = $script:WinDivZeroWidth;
   } else {
      $name = $script:WinDivBlank;
      $pad = $script:WinDivBlank;
   }

   while ($taken.Contains($name)) { $name += $pad; }
   return $name;
}

function New-WinDivLink {
   param (
      [Parameter(Mandatory = $true)]
      [string] $Path,

      [Parameter(Mandatory = $true)]
      [string] $Target,

      [AllowEmptyString()]
      [string] $Description = '',

      [Parameter(Mandatory = $true)]
      [string] $AppId
   )

   [WinTaskbarDivs.Shortcut]::Create($Path, $Target, $Target, 0, $Description, $AppId);
}
