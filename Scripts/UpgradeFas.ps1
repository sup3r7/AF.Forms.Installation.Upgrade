#
# Upgrade FAS installation
#



$formType = "Fas"

$Global:tempFilePath = "./$($formType)tempLogFile.txt"

if(Test-Path -Path $Global:tempFilePath)
{
   Remove-Item -Path $Global:tempFilePath -Force -ErrorAction SilentlyContinue
}

New-Item -Path $Global:tempFilePath -ItemType File | Out-Null

#$scriptPath = "C:\Program Files (x86)\FormFlex System"
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

#Create paths to temporary folders
$tempFormTypePath = Join-Path $scriptPath -ChildPath "$($formType)TempFolder"
$tempMigratePath = Join-Path $scriptPath -ChildPath "MigrateTempFolder"

#Check if this path exists if yes remove it and create a new one
if( Test-Path -Path $tempFormTypePath)
{
    Remove-Item -Path $tempFormTypePath -Recurse -Force
}

#Check if this path exists if yes remove it and create a new one
if( Test-Path -Path $tempMigratePath)
{
    Remove-Item -Path $tempMigratePath -Recurse -Force
}

#Create temporary folders
$tempFormTypeFolder = New-Item -ItemType Directory -Path $tempFormTypePath
$tempMigrateFolder = New-Item -ItemType Directory -Path $tempMigratePath

$zipPath = (Get-ChildItem -Path $scriptPath -Recurse -Include "*.zip" | Select-Object -First 1).FullName

#If the zip file is blocked by microsoft unblock it
Unblock-File $zipPath

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
    
        # FAS
        if( $childPath -eq $formType)
        {
            $shell.Namespace($tempFormTypeFolder.FullName).copyhere($item)
        }

        # Migrator
        if( $childPath -eq "Migrator")
        {
            $shell.Namespace($tempMigrateFolder.FullName).copyhere($item)
        }
    }

    #
    # Replacing client and server files
    #
    $formPartTempFullPath = Join-Path $tempFormTypeFolder.FullName -ChildPath "$formType\"

    # Replacing Client files
    Write-Output "Info: Replacing Client XAP file..."  | Out-file $Global:tempFilePath -Append
    
    $clientBinPath = Join-Path $scriptPath "$formType\Client\ClientBin\"

    Remove-Item -Path "$clientBinPath\*" -Force 
    
    Copy-Item (Get-ChildItem -Path (join-path $tempFormTypeFolder.FullName "\$formType\Client") -Recurse -Include "*.xap" ) -Destination $clientBinPath -Force

    # Replacing Server files
    Write-Output "Info: Replacing Server dll files..." | Out-file $Global:tempFilePath -Append
    
    $serverBinPath =  Join-Path $scriptPath "$formType\Server\Bin\"

    Remove-Item -Path "$serverBinPath\*" -Force -Include "*.dll" 

    Copy-Item (Get-ChildItem -Path (join-path $tempFormTypeFolder.FullName "\$formType\Server") -Recurse -Include "*.dll" ) -Destination $serverBinPath -Force 

    #
    # Migrating database
    #
 <#   Write-Output "Info: Migrating database..." | Out-file $Global:tempFilePath -Append
    
    $xmlName = "web.config"
    
    $formTypeDbContext = $formType + "DbContext"
    
    $xml = [xml](Get-Content "$scriptPath/$formType/Server/$xmlName") 

    $connectionString = (Select-Xml -Xml $xml -XPath "//connectionStrings/add[@name='$formTypeDbContext']/@connectionString").Node

    New-ModuleManifest -Path (Join-Path $tempMigratePath "Migrator\Af.Forms.Tools.Fls.DataBaseMigrator.psd1") -Author "FormFlex Developer" -CompanyName "AF Industry AB" -RequiredAssemblies (Get-ChildItem -Path $tempMigratePath -Recurse -Include "*.dll")
    
    $module =  (Get-ChildItem -Path $tempMigratePath -Recurse | Where-Object { $_.Name -eq "Af.Forms.Tools.Fls.DataBaseMigrator.dll" })

    if(!$module)
    {
       Write-Output "Error: Could not find Af.Forms.Tools.Fls.DataBaseMigrator.dll" | Out-file $Global:tempFilePath -Append
    }

    $psModelInfo = Import-Module $module.FullName  -PassThru

    $result =  Update-MigrationToLatest -ConnectionString $connectionString.'#text' -FormType $formType

    Write-Output "Info: Migration result: $result"  | Out-file $Global:tempFilePath -Append
    
    Remove-Module "Af.Forms.Tools.Fls.DataBaseMigrator" -Force
    #>
    return (Get-Content $Global:tempFilePath )

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