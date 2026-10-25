<#
.SYNOPSIS
One-time setup for WinTaskbarDivs (the `divs` command).

.DESCRIPTION
1. Grants your user Modify rights on C:\Program Files\WinTaskbarDivs (one UAC
   prompt), so `divs` never needs an elevated shell afterwards.
2. Links Documents\PowerShell\Modules\WinTaskbarDivs to this repo's module
   folder (a junction), so `divs` autoloads in every pwsh session and repo
   edits take effect in new sessions. Your profile isn't touched.

Run with -Uninstall to undo both steps and delete the helper DLL cache in
%LOCALAPPDATA%\WinTaskbarDivs. Existing dividers are left in place.
#>
[CmdletBinding()]
param (
   [switch] $Uninstall
)

$ErrorActionPreference = 'Stop';

$root = 'C:\Program Files\WinTaskbarDivs';
$moduleSource = Join-Path $PSScriptRoot 'WinTaskbarDivs';
$modulesDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules';
$moduleLink = Join-Path $modulesDir 'WinTaskbarDivs';
# Resolved before elevating, so the grant goes to *this* user even if UAC
# asks for a different admin account.
$sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value;

function Invoke-ElevatedCmd {
   param (
      [Parameter(Mandatory = $true)]
      [string] $CommandLine
   )

   try {
      $proc = Start-Process cmd.exe -ArgumentList "/s /c `"$CommandLine`"" -Verb RunAs -WindowStyle Hidden -Wait -PassThru;
   } catch {
      throw "Elevation was cancelled or failed: $_";
   }
   if ($proc.ExitCode -ne 0) {
      throw "Elevated command failed (exit $($proc.ExitCode)): $CommandLine";
   }
}

function Test-RootWritable {
   if (-not (Test-Path -LiteralPath $root)) { return $false; }
   $probe = Join-Path $root ".write-test-$PID";
   try {
      [System.IO.File]::WriteAllText($probe, '');
      Remove-Item -LiteralPath $probe -Force;
      return $true;
   } catch {
      return $false;
   }
}

if ($Uninstall) {
   if (Test-Path -LiteralPath $moduleLink) {
      $item = Get-Item -LiteralPath $moduleLink -Force;
      if ($item.LinkType -eq 'Junction') {
         # Deletes only the junction, never the repo files behind it
         [System.IO.Directory]::Delete($moduleLink, $false);
         Write-Host "Removed module link $moduleLink" -ForegroundColor Green;
      } else {
         Write-Warning "$moduleLink isn't a junction made by install.ps1; leaving it alone.";
      }
   }

   $cacheDir = Join-Path $env:LOCALAPPDATA 'WinTaskbarDivs';
   if (Test-Path -LiteralPath $cacheDir) {
      Remove-Item -LiteralPath $cacheDir -Recurse -Force;
      Write-Host "Removed helper DLL cache $cacheDir" -ForegroundColor Green;
   }

   if (Test-Path -LiteralPath $root) {
      Write-Host 'Removing your write access to the dividers folder (UAC prompt)...';
      Invoke-ElevatedCmd "icacls `"$root`" /remove:g *$sid";
      Write-Host "Revoked write access on $root (dividers in it were kept)." -ForegroundColor Green;
   }
   return;
}

# --- 1. folder access ---------------------------------------------------------

if (Test-RootWritable) {
   Write-Host "Already have write access to $root" -ForegroundColor DarkGray;
} else {
   Write-Host "Granting your user write access to $root (UAC prompt)...";
   # The parentheses matter: without them cmd treats "&& icacls" as part of the if body.
   Invoke-ElevatedCmd "(if not exist `"$root`" mkdir `"$root`") && icacls `"$root`" /grant *${sid}:(OI)(CI)M";
   if (-not (Test-RootWritable)) { throw "Still can't write to $root after granting access."; }
   Write-Host "Granted write access to $root" -ForegroundColor Green;
}

# --- 2. module link -----------------------------------------------------------

if (-not (Test-Path -LiteralPath $modulesDir)) {
   New-Item -ItemType Directory -Path $modulesDir | Out-Null;
}

if (Test-Path -LiteralPath $moduleLink) {
   $item = Get-Item -LiteralPath $moduleLink -Force;
   $target = @($item.Target)[0];
   if ($item.LinkType -eq 'Junction' -and $target -and ((Resolve-Path -LiteralPath $target).ProviderPath -eq (Resolve-Path -LiteralPath $moduleSource).ProviderPath)) {
      Write-Host "Module already linked: $moduleLink" -ForegroundColor DarkGray;
   } else {
      throw "$moduleLink already exists and doesn't point at this repo. Move it aside and re-run.";
   }
} else {
   New-Item -ItemType Junction -Path $moduleLink -Target $moduleSource | Out-Null;
   Write-Host "Linked $moduleLink -> $moduleSource" -ForegroundColor Green;
}

Write-Host "`nDone. Try: divs new -Color blue -Icon code -Tooltip Dev" -ForegroundColor Cyan;
