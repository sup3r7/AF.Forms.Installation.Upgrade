#
# Wrapper script for upgrading all or some FormFlex servers
#

try
{

    # Get rootPath for scripts
    $scriptPath = split-path -parent $MyInvocation.MyCommand.Definition;
    $rootPath = split-path -parent $scriptpath;
    $logfile = "$rootPath\Log\logfile.txt"
    $xamlPath = "$rootPath\Views\MainWindow.xaml"
    Import-Module "$rootPath\Modules\UpgradeFormFlex.psm1"

    Start-UpgradeWindow -ScriptPath $scriptPath -LogFilePath $logfile -XamlPath $xamlPath

}
catch [System.Net.WebException],[System.Exception]
{
    Write-Output "Unhandled exception in Wrapper script" | Out-File -FilePath $logfile
}
finally
{
    # Clean-up
    Remove-Module UpgradeFormFlex
    Write-Host "Done upgrading FormFlex!" -ForegroundColor Green
}

