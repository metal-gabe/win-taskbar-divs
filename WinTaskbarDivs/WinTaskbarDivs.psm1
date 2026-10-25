foreach ($file in Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private'), (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1') {
   . $file.FullName;
}

Initialize-WinDivNative;

# --- tab completion ----------------------------------------------------------

$iconCompleter = {
   param ($commandName, $parameterName, $wordToComplete)
   $script:WinDivIcons.Keys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', ('U+{0:X4}' -f $script:WinDivIcons[$_]));
   };
};

$colorCompleter = {
   param ($commandName, $parameterName, $wordToComplete)
   $script:WinDivColors.Keys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
      $hex = $script:WinDivColors[$_];
      [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $(if ($hex) { $hex } else { 'stock folder color' }));
   };
};

$idCompleter = {
   param ($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
   $takesAll = $commandName -in 'Remove-WinDiv', 'Update-WinDiv' -or
      ($commandName -eq 'divs' -and $fakeBoundParameters['Action'] -in 'remove', 'rm', 'rebuild');
   if ($takesAll -and 'all' -like "$wordToComplete*") {
      [System.Management.Automation.CompletionResult]::new('all', 'all', 'ParameterValue', 'every divider');
   }
   Read-WinDivManifests -Root (Get-WinDivRoot) | Where-Object { $_.id -like "$wordToComplete*" } | ForEach-Object {
      [System.Management.Automation.CompletionResult]::new($_.id, $_.id, 'ParameterValue', $(if ($_.tooltip) { $_.tooltip } else { $_.id }));
   };
};

$lookCommands = 'divs', 'New-WinDiv', 'Show-WinDivPreview';
Register-ArgumentCompleter -CommandName $lookCommands -ParameterName Icon -ScriptBlock $iconCompleter;
Register-ArgumentCompleter -CommandName $lookCommands -ParameterName Color -ScriptBlock $colorCompleter;
Register-ArgumentCompleter -CommandName $lookCommands -ParameterName IconColor -ScriptBlock $colorCompleter;
Register-ArgumentCompleter -CommandName 'divs', 'Get-WinDiv', 'Remove-WinDiv', 'Update-WinDiv', 'Open-WinDiv' -ParameterName Id -ScriptBlock $idCompleter;
