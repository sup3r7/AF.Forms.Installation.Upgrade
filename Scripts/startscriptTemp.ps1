. '.\UpgradeUtilityFunctionScript.ps1'
  $scriptPath = split-path -parent $MyInvocation.MyCommand.Definition;
Setup-Controls -ScriptPath $scriptPath