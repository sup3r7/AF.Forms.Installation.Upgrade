  Param([Parameter(Mandatory=$true,
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]$formType,
        [Parameter(Mandatory=$false,
        ValueFromPipeline = $false,
        ValueFromPipelineByPropertyName=$false,
        Position=1)]$Credentials)

#$scriptPath = "C:\Program Files (x86)\FormFlex System"
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

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
   Remove-Item -Path $tempMigratePath -Force -Recurse
}

$tempMigrateFolder =  New-Item -Path $tempMigratePath -ItemType Directory
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
    
    $xmlName = "web.config"
    
    # start here 
    $formTypeDbContext = $formType + "DbContext"

    $xml = [xml](Get-Content "$scriptPath\$formType\Server\Web.config") 

    $connectionString = (Select-Xml -Xml $xml -XPath "//connectionStrings/add[@name='$formTypeDbContext']/@connectionString").Node

    $stringBuilder = new-object System.Data.SqlClient.SqlConnectionStringBuilder -ArgumentList $connectionString.'#text'


    $path = @{$true="SQLSERVER:\SQL\$($stringBuilder.DataSource)\Databases\Forms$($formType)DB\Tables\dbo.$($formType)Versions";$false="SQLSERVER:\SQL\$($stringBuilder.DataSource)\DEFAULT\Databases\FormsFASDB\Tables\dbo.FasVersions"}[$stringBuilder.DataSource.Split('\').Count -gt 1] 


    $scriptBlockAction = {    
    
                            Param( $localPath, $localFormType, $localScriptPath)

                            . "$localScriptPath\Initialize-SqlPsEnvironment.ps1"

                            Push-Location

                            Set-Location -Path $localPath

                            $result  = Invoke-Sqlcmd -Query "SELECT [VersionNumber] FROM dbo.$($localFormType)Versions WHERE Id = 1" -SuppressProviderContextWarning
                            
                            Pop-Location                   
                            
                            return $result.VersionNumber 
                          }

    $splitResult = $stringBuilder.DataSource.Split('\')
    
    $computerName = $splitResult[0]
    
    if( ($computerName -match "\d+.\d+.\d+.\d+") -and ($splitResult.Count -le 1))
    {   
        $hostIpAddress = $computerName
        
        $computerName = [System.Net.dns]::GetHostbyAddress($computerName).HostName
    }

    $versionNumber = ""
    
    if($computerName -eq $env:COMPUTERNAME)
    {
    
     $databaseVersionNumber = $scriptBlockAction.Invoke($path,$formType,$scriptPath)
    
    }
    else
    {
                #$RemoteUser = "Administrator"
			    
                #$RemotePWord = ConvertTo-SecureString -String "QA321ik!" -AsPlainText -Force
			    
                #$RemoteCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RemoteUser, $RemotePWord
     
                $Session = New-PSSession -ComputerName $hostIpAddress -Credential $Credentials
                
                $databaseVersionNumber = Invoke-Command -Session $Session  -ScriptBlock $scriptBlockAction -ArgumentList $path,$formType,$scriptPath

                Remove-PSSession -Session $Session

    }

    #stop here

    $isVersionNumberEqual = $false

    $isVersionNumberEqual = $dllVersionNumber -eq $databaseVersionNumber
    
    #
    # Migrating database
    #
    Write-Output "Info: Migrating database..." | Out-file $Global:tempFilePath -Append
    

    #$connectionString ="Data Source=192.168.44.83;Initial Catalog=FormsFASDB;User Id=fasDbUser;Password=Zxcvbn.0"
    
    New-ModuleManifest -Path (Join-Path $tempMigratePath "Migrator\Af.Forms.Tools.Fls.DataBaseMigrator.psd1") -Author "FormFlex Developer" -CompanyName "AF Industry AB" -RequiredAssemblies (Get-ChildItem -Path $tempMigratePath -Recurse -Include "*.dll")
    
    $module =  (Get-ChildItem -Path $tempMigratePath -Recurse | Where-Object { $_.Name -eq "Af.Forms.Tools.Fls.DataBaseMigrator.dll" })

    if(!$module)
    {
       Write-Output "Error: Could not find Af.Forms.Tools.Fls.DataBaseMigrator.dll" | Out-file $Global:tempFilePath -Append
    }

    $fileStream = ([System.IO.FileInfo] (Get-Item $module.FullName )).OpenRead();
    $assemblyBytes = new-object byte[] $fileStream.Length
    $fileStream.Read($assemblyBytes, 0, $fileStream.Length);
    $fileStream.Close();

    $assemblyLoaded = [System.Reflection.Assembly]::Load($assemblyBytes);

    Import-Module $assemblyLoaded -Verbose

    $result =  Update-MigrationToLatest -ConnectionString $connectionString.'#text' -FormType $formType

    Write-Output "Info: Migration result: $result"  | Out-file $Global:tempFilePath -Append
    
     Get-Module '*Af.Forms.Tools.Fls.DataBaseMigrator*'| Remove-Module 

    return @{ Content = (Get-Content $Global:tempFilePath ); IsVersionNumberEqual = $isVersionNumberEqual; DllVersionNumber = $dllVersionNumber ; DatabaseVersionNumber = $databaseVersionNumber  } 

}
catch [System.Net.WebException],[System.Exception]
{
    Write-Output "Error: Unhandled exception in UpgradeFas script" | Out-file $Global:tempFilePath -Append
    Write-Output "Error: Exception Type: $($_.Exception.GetType().FullName)" | Out-file $Global:tempFilePath -Append
    Write-Output "Error: Exception Message: $($_.Exception.Message)" | Out-file $Global:tempFilePath -Append

    return @{ Content = (Get-Content $Global:tempFilePath ); IsVersionNumberEqual = $isVersionNumberEqual; DllVersionNumber = $dllVersionNumber ; DatabaseVersionNumber = $result.VersionNumber  } 
}
finally
{
}