  Param([Parameter(Mandatory=$true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]$formType)

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition


$Global:tempFilePath = "$scriptPath/$($formType)tempLogFile.txt"

if(Test-Path -Path $Global:tempFilePath)
{
   Remove-Item -Path $Global:tempFilePath -Force -ErrorAction SilentlyContinue
}

$tempMigratePath = Join-Path $scriptPath -ChildPath "MigrateTempFolder"

$firstDll = Get-ChildItem -Path $tempMigratePath -Include "*.dll" -Recurse | Sort-Object Name | Select -First 1

$dllVersionNumber = $firstDll.VersionInfo.FileVersion.Substring(0,$firstDll.VersionInfo.FileVersion.Length - 2) 

if([string]::IsNullOrEmpty($dllVersionNumber))
{
  "Error: Could not find any dlls" | Out-File -FilePath $Global:tempFilePath -Append
}

$xmlName = "web.config"
    
$formTypeDbContext = $formType + "DbContext"

$xml = [xml](Get-Content "$scriptPath/$formType/Server/$xmlName") 

$connectionString = (Select-Xml -Xml $xml -XPath "//connectionStrings/add[@name='$formTypeDbContext']/@connectionString").Node

$stringBuilder = new-object System.Data.SqlClient.SqlConnectionStringBuilder -ArgumentList $connectionString.'#text'

$path = @{$true="SQLSERVER:\SQL\$($stringBuilder.DataSource)\Databases\Forms$($formType)DB\Tables\dbo.$($formType)Versions";$false="SQLSERVER:\SQL\$($stringBuilder.DataSource)\DEFAULT\Databases\FormsFASDB\Tables\dbo.FasVersions"}[$stringBuilder.DataSource.Split('\').Count -gt 1] 


    
. "$scriptPath\Initialize-SqlPsEnvironment.ps1" | Out-File $Global:tempFilePath -Append

Push-Location

Set-Location -Path $path

$result  = Invoke-Sqlcmd -Query "UPDATE [Forms($formType)DB].[dbo].[($formType)Versions] SET [VersionNumber] = '$dllVersionNumber' WHERE [Id] = 1" -SuppressProviderContextWarning


 
Pop-Location

"Success: Successfully updated version number" | Out-File -FilePath $Global:tempFilePath -Append

return  @{ Content = (Get-Content $Global:tempFilePath ); DLLVersionNumber = $dllVersionNumber  }