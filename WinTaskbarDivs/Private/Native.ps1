# Compiles Native.cs to a DLL cached under %LOCALAPPDATA%\WinTaskbarDivs and
# loads it from disk. Loading Add-Type's in-memory assembly directly can be
# blocked by Defender (0x800700E1, "potentially unwanted software"); a stable
# on-disk DLL isn't. The cache key covers the source and the pwsh version, so
# edits to Native.cs recompile automatically (in a new session: types can't be
# unloaded).
function Initialize-WinDivNative {
   if ('WinTaskbarDivs.IconRenderer' -as [type]) { return; }

   $source = Join-Path $PSScriptRoot 'Native.cs';
   $sha = [System.Security.Cryptography.SHA256]::Create();
   try {
      $bytes = [System.IO.File]::ReadAllBytes($source) + [System.Text.Encoding]::UTF8.GetBytes([string]$PSVersionTable.PSVersion);
      $hash = ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').Substring(0, 16);
   } finally {
      $sha.Dispose();
   }

   $cacheDir = Join-Path $env:LOCALAPPDATA 'WinTaskbarDivs';
   $dll = Join-Path $cacheDir "WinTaskbarDivs.Native.$hash.dll";

   if (-not (Test-Path -LiteralPath $dll)) {
      if (-not (Test-Path -LiteralPath $cacheDir)) {
         New-Item -ItemType Directory -Path $cacheDir | Out-Null;
      }
      # Drop builds of older Native.cs versions (ignore ones loaded by other sessions)
      Get-ChildItem -LiteralPath $cacheDir -Filter 'WinTaskbarDivs.Native.*.dll' |
         Remove-Item -Force -ErrorAction SilentlyContinue;

      # System.Drawing's dependencies vary by .NET version (e.g. .NET 10 split out
      # System.Private.Windows.GdiPlus), so reference whatever ships with this pwsh.
      $refs = @(
         'System.Runtime',
         'System.Collections',
         'System.ComponentModel.Primitives',
         'System.Runtime.InteropServices'
      );
      foreach ($name in 'System.Drawing.Common', 'System.Drawing.Primitives', 'System.Private.Windows.GdiPlus', 'System.Private.Windows.Core') {
         $ref = Join-Path $PSHOME "$name.dll";
         if (Test-Path -LiteralPath $ref) { $refs += $ref; }
      }

      # Build to a temp name first so a failed compile never leaves a bad cache entry.
      $temp = "$dll.$PID.tmp";
      Add-Type -Path $source -ReferencedAssemblies $refs -OutputAssembly $temp -OutputType Library;
      Move-Item -LiteralPath $temp -Destination $dll -Force;
   }

   if (-not ('WinTaskbarDivs.IconRenderer' -as [type])) {
      Add-Type -Path $dll;
   }
}
