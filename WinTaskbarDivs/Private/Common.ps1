$script:WinDivDefaultRoot = 'C:\Program Files\WinTaskbarDivs';
$script:WinDivManifestName = 'divider.json';
$script:WinDivAppIdPrefix = 'WinTaskbarDivs.';
$script:WinDivPinnedDir = Join-Path $env:APPDATA 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar';

# $env:WINTASKBARDIVS_ROOT overrides the output location (handy for trying things out).
function Get-WinDivRoot {
   if ($env:WINTASKBARDIVS_ROOT) { return $env:WINTASKBARDIVS_ROOT; }
   return $script:WinDivDefaultRoot;
}

function Assert-WinDivWritable {
   param (
      [Parameter(Mandatory = $true)]
      [string] $Root
   )

   if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
      throw "Output folder '$Root' doesn't exist. Run install.ps1 from the WinTaskbarDivs repo first.";
   }

   $probe = Join-Path $Root ".write-test-$PID";
   try {
      [System.IO.File]::WriteAllText($probe, '');
      Remove-Item -LiteralPath $probe -Force;
   } catch {
      throw "No write access to '$Root'. Run install.ps1 from the WinTaskbarDivs repo once (it grants your user access).";
   }
}

function ConvertTo-WinDivSlug {
   param (
      [AllowEmptyString()]
      [string] $Text
   )

   $slug = ($Text.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-');
   if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40).TrimEnd('-'); }
   return $slug;
}

function Test-WinDivId {
   param (
      [string] $Id
   )

   # 'all' is reserved: 'divs rebuild all' / 'divs remove all' mean every divider.
   return $Id -cmatch '^[a-z0-9][a-z0-9-]{0,39}$' -and $Id -ne 'all';
}

# Reads every divider.json under the root. Each result gets a Path property.
function Read-WinDivManifests {
   param (
      [Parameter(Mandatory = $true)]
      [string] $Root
   )

   if (-not (Test-Path -LiteralPath $Root)) { return; }

   foreach ($dir in Get-ChildItem -LiteralPath $Root -Directory) {
      # New-WinDiv's staging and backup folders (ids can't start with a dot)
      if ($dir.Name.StartsWith('.')) { continue; }
      $file = Join-Path $dir.FullName $script:WinDivManifestName;
      if (-not (Test-Path -LiteralPath $file)) { continue; }
      $manifest = Get-Content -LiteralPath $file -Raw -Encoding utf8 | ConvertFrom-Json;
      $manifest | Add-Member -NotePropertyName Path -NotePropertyValue $dir.FullName -Force;
      $manifest;
   }
}

# Targets of the .lnk files currently pinned to the taskbar.
function Get-WinDivPinnedTargets {
   if (-not (Test-Path -LiteralPath $script:WinDivPinnedDir)) { return @(); }

   foreach ($lnk in Get-ChildItem -LiteralPath $script:WinDivPinnedDir -Filter '*.lnk') {
      try {
         [pscustomobject]@{
            Name   = $lnk.BaseName;
            Target = [WinTaskbarDivs.Shortcut]::Read($lnk.FullName)[0];
         };
      } catch {
         Write-Verbose "Skipping unreadable pin '$($lnk.Name)': $_";
      }
   }
}
