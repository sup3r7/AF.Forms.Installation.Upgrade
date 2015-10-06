

#$scriptPath = "C:\Program Files (x86)\FormFlex System"
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

$formType = "Fas"

$Global:tempFilePath = "$scriptPath/$($formType)tempLogFile.txt"

if(Test-Path -Path $Global:tempFilePath)
{
   Remove-Item -Path $Global:tempFilePath -Force -ErrorAction SilentlyContinue
}

New-Item -Path $Global:tempFilePath -ItemType File | Out-Null

$tempMigratePath = Join-Path $scriptPath -ChildPath "MigrateTempFolder"
#Check if this path exists if yes remove it and create a new one
if( Test-Path -Path $tempMigratePath)
{
    Remove-Item -Path $tempMigratePath -Recurse -Force
}

$tempMigrateFolder = New-Item -ItemType Directory -Path $tempMigratePath

$zipPath =  (Get-ChildItem -Path $scriptPath -Recurse -Include "*.zip" | Select -First 1).FullName


#Create a shell comobject to make the unzipping
$shell = new-object -ComObject shell.application

if([string]::IsNullOrEmpty($zipPath))
{
     Write-Output "Error: Could not find any zip file" | Out-file $Global:tempFilePath -Append
    Break;
}


try
{
    #
    # Unpack artifact
    #

    Write-Output "Info: Unzipping artifact..."  | Out-file $Global:tempFilePath -Append
 

    $zip = $shell.NameSpace($zipPath)

    foreach( $item in $zip.Items())
    {
        $childPath = Split-Path $item.Path -Leaf
    
        # Migrator
        if( $childPath -eq "Migrator")
        {
            $shell.Namespace($tempMigrateFolder.FullName).copyhere($item)
        }
    }

    $firstDll = Get-ChildItem -Path $tempMigrateFolder.FullName -Include "*.dll" -Recurse | Sort-Object Name | Select -First 1
    
    $dllVersionNumber =$firstDll.VersionInfo.FileVersion.Substring(0,$firstDll.VersionInfo.FileVersion.Length - 2) 
    
    . "$scriptPath\Initialize-SqlPsEnvironment.ps1"

    Push-Location

    Set-Location -Path "SQLSERVER:\SQL\NOVDB01\DEFAULT\Databases\FormsFASDB\Tables\dbo.FasVersions"

    $result  = Invoke-Sqlcmd -Query "SELECT [VersionNumber] FROM dbo.FasVersions WHERE Id = 1"
     
    Pop-Location

    $isVersionNumberEqual = $dllVersionNumber -eq $result.VersionNumber
    #
    # Migrating database
    #
    Write-Output "Info: Migrating database..." | Out-file $Global:tempFilePath -Append
    
    $xmlName = "web.config"
    
    $formTypeDbContext = $formType + "DbContext"
    
    $xml = [xml](Get-Content "$scriptPath/$formType/Server/$xmlName") 

    
    $connectionString ="Data Source=192.168.44.83;Initial Catalog=FormsFASDB;User Id=fasDbUser;Password=Zxcvbn.0"
    
    New-ModuleManifest -Path (Join-Path $tempMigratePath "Migrator\Af.Forms.Tools.Fls.DataBaseMigrator.psd1") -Author "FormFlex Developer" -CompanyName "AF Industry AB" -RequiredAssemblies (Get-ChildItem -Path $tempMigratePath -Recurse -Include "*.dll")
    
    $module =  (Get-ChildItem -Path $tempMigratePath -Recurse | Where-Object { $_.Name -eq "Af.Forms.Tools.Fls.DataBaseMigrator.dll" })

    if(!$module)
    {
       Write-Output "Error: Could not find Af.Forms.Tools.Fls.DataBaseMigrator.dll" | Out-file $Global:tempFilePath -Append
    }

    $psModelInfo = Import-Module $module.FullName  -PassThru

    $result =  Update-MigrationToLatest -ConnectionString $connectionString -FormType $formType

    Write-Output "Info: Migration result: $result"  | Out-file $Global:tempFilePath -Append
    
    Remove-Module "Af.Forms.Tools.Fls.DataBaseMigrator" -Force

    return  @{ Content = (Get-Content $Global:tempFilePath ); IsVersionNumberEqual = $isVersionNumberEqual } 

}
catch [System.Net.WebException],[System.Exception]
{
    Write-Output "Error: Unhandled exception in UpgradeFas script" | Out-file $Global:tempFilePath -Append
    Write-Output "Error: Exception Type: $($_.Exception.GetType().FullName)" | Out-file $Global:tempFilePath -Append
    Write-Output "Error: Exception Message: $($_.Exception.Message)" | Out-file $Global:tempFilePath -Append

    return (Get-Content $Global:tempFilePath)
}
finally
{
}