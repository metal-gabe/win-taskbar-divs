# Friendly names for Segoe Fluent Icons codepoints. Any other icon can be used
# by codepoint (e.g. `-Icon U+E8F1`); browse them with the Windows "Character
# Map" app (font: Segoe Fluent Icons) or https://learn.microsoft.com/windows/apps/design/style/segoe-fluent-icons-font
$script:WinDivIcons = [ordered]@{
   'airplane'   = 0xE709;
   'bolt'       = 0xE945;
   'book'       = 0xE8F1;
   'brush'      = 0xE790;
   'bug'        = 0xEBE8;
   'calendar'   = 0xE787;
   'camera'     = 0xE722;
   'car'        = 0xE804;
   'cart'       = 0xE7BF;
   'chat'       = 0xE8BD;
   'cloud'      = 0xE753;
   'code'       = 0xE943;
   'contact'    = 0xE77B;
   'devtools'   = 0xEC7A;
   'document'   = 0xE8A5;
   'download'   = 0xE896;
   'edit'       = 0xE70F;
   'flag'       = 0xE7C1;
   'folder'     = 0xE8B7;
   'game'       = 0xE7FC;
   'globe'      = 0xE774;
   'headphones' = 0xE7F6;
   'heart'      = 0xEB51;
   'home'       = 0xE80F;
   'lightbulb'  = 0xEA80;
   'list'       = 0xE8A4;
   'lock'       = 0xE72E;
   'mail'       = 0xE715;
   'mic'        = 0xE720;
   'monitor'    = 0xE7F4;
   'music'      = 0xE8D6;
   'people'     = 0xE716;
   'phone'      = 0xE717;
   'photo'      = 0xEB9F;
   'pin'        = 0xE718;
   'puzzle'     = 0xEA86;
   'robot'      = 0xE99A;
   'search'     = 0xE721;
   'settings'   = 0xE713;
   'shield'     = 0xEA18;
   'star'       = 0xE734;
   'terminal'   = 0xE756;
   'upload'     = 0xE898;
   'video'      = 0xE714;
   'wifi'       = 0xE701;
   'work'       = 0xE821;
};

# Resolves a friendly name, "U+E943" / "0xE943" / "E943", or a literal
# character to the string to draw.
function Resolve-WinDivIcon {
   param (
      [Parameter(Mandatory = $true)]
      [string] $Icon
   )

   $key = $Icon.Trim().ToLowerInvariant();
   if ($script:WinDivIcons.Contains($key)) {
      return [string][char]$script:WinDivIcons[$key];
   }

   if ($Icon -match '^(?:U\+|0x)?([0-9A-Fa-f]{4,5})$') {
      return [char]::ConvertFromUtf32([Convert]::ToInt32($Matches[1], 16));
   }

   # A single literal character (including surrogate pairs)
   $info = [System.Globalization.StringInfo]::new($Icon);
   if ($info.LengthInTextElements -eq 1) {
      return $Icon;
   }

   throw "Unknown icon '$Icon'. Run 'divs icons' for names, or pass a codepoint like U+E943.";
}
