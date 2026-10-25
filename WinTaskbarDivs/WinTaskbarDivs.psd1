@{
   RootModule           = 'WinTaskbarDivs.psm1';
   ModuleVersion        = '1.0.0';
   GUID                 = '6b0e9a4e-3f7c-4f61-9a3d-1c2f5d8e7b40';
   Author               = 'Metal Gabe';
   Description          = 'Creates do-nothing, folder-looking pseudo-apps to pin as Windows 11 taskbar dividers.';
   PowerShellVersion    = '7.2';
   CompatiblePSEditions = @('Core');
   FormatsToProcess     = @('WinTaskbarDivs.Format.ps1xml');
   FunctionsToExport    = @(
      'divs',
      'New-WinDiv',
      'Get-WinDiv',
      'Remove-WinDiv',
      'Update-WinDiv',
      'Open-WinDiv',
      'Show-WinDivPreview',
      'Get-WinDivIcon',
      'Get-WinDivColor'
   );
   CmdletsToExport      = @();
   VariablesToExport    = @();
   AliasesToExport      = @();
}
