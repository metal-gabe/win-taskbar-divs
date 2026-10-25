$script:WinDivCsc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe';

# Compiles the do-nothing divider exe with the icon embedded as its main icon.
function Build-WinDivStub {
   param (
      [Parameter(Mandatory = $true)]
      [string] $OutFile,

      [Parameter(Mandatory = $true)]
      [string] $IconFile,

      [AllowEmptyString()]
      [string] $Title = ''
   )

   if (-not (Test-Path -LiteralPath $script:WinDivCsc)) {
      throw "C# compiler not found at '$script:WinDivCsc' (it ships with Windows' .NET Framework 4.x).";
   }

   $escaped = $Title.Replace('\', '\\').Replace('"', '\"');
   $source = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Stub.cs.template') -Raw).Replace('{{TITLE}}', $escaped);
   $temp = Join-Path ([System.IO.Path]::GetTempPath()) "divs-stub-$([guid]::NewGuid().ToString('N')).cs";

   try {
      [System.IO.File]::WriteAllText($temp, $source, [System.Text.UTF8Encoding]::new($true));
      $output = & $script:WinDivCsc /nologo /target:winexe /optimize+ /utf8output "/win32icon:$IconFile" "/out:$OutFile" $temp 2>&1;
      if ($LASTEXITCODE -ne 0) {
         throw "csc.exe failed (exit $LASTEXITCODE):`n$($output -join "`n")";
      }
   } finally {
      Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue;
   }
}
