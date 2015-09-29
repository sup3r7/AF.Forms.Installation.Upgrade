#
# Upgrade FLS installation
#

$formType = "Fls"
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
    Write-Host "Could not find any zip file" -ForegroundColor Red
    Break;
}

try
{
    #
    # Stop SitComm service
    #
    Write-Host "Stopping SitComm..." -ForegroundColor Green
	$sitComm = Get-Service SitCommWindowsService -ErrorAction SilentlyContinue
	if ($sitComm) 
	{	
		Stop-Service SitCommWindowsService -WarningAction SilentlyContinue
	}

    #
    # Unpack artifact
    #
    Write-Host "Unzipping artifact..." -ForegroundColor Green

    $zip = $shell.NameSpace($zipPath)

    foreach( $item in $zip.Items())
    {
        $childPath = Split-Path $item.Path -Leaf
    
        # FLS
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

    #
    # Replacing Client files
    #
    Write-Host "Replacing Client XAP file..." -ForegroundColor Green

    $clientBinPath = Join-Path $scriptPath "$formType\Client\ClientBin\"

    Remove-Item -Path "$clientBinPath\*" -Force 
    
    Copy-Item (Get-ChildItem -Path (join-path $tempFormTypeFolder.FullName "\$formType\Client") -Recurse -Include "*.xap" ) -Destination $clientBinPath -Force

    #
    # Replacing Server files
    #
    Write-Host "Replacing Server dll files..." -ForegroundColor Green
    
    $serverBinPath =  Join-Path $scriptPath "$formType\Server\Bin\"

    Remove-Item -Path "$serverBinPath\*" -Force -Include "*.dll" 

    Copy-Item (Get-ChildItem -Path (join-path $tempFormTypeFolder.FullName "\$formType\Server") -Recurse -Include "*.dll" ) -Destination $serverBinPath -Force 

    #
    # Replacing SitComm files
    #
    Write-Host "Replacing SitComm files..." -ForegroundColor Green
    
    $sitCommBinPath =  Join-Path $scriptPath "$formType\WindowsService\"

    Remove-Item -Path "$sitCommBinPath\*" -Force -Exclude "*.exe.config","*.exe"

    Copy-Item (Get-ChildItem -Path (join-path $tempFormTypeFolder.FullName "\$formType\WindowsService") -Recurse -Include "*.dll" ) -Destination $sitCommBinPath -Force 

    #
    # Migrating database
    #
    Write-Host "Migrating database..." -ForegroundColor Green

    $xmlName = "web.config"
    $formTypeDbContext = $formType + "DbContext"
    $xml = [xml](Get-Content "$scriptPath/$formType/Server/$xmlName") 

    $connectionString = (Select-Xml -Xml $xml -XPath "//connectionStrings/add[@name='$formTypeDbContext']/@connectionString").Node

    New-ModuleManifest -Path (Join-Path $tempMigratePath "Migrator\Af.Forms.Tools.Fls.DataBaseMigrator.psd1") -Author "FormFlex Developer" -CompanyName "AF Industry AB" -RequiredAssemblies (Get-ChildItem -Path $tempMigratePath -Recurse -Include "*.dll")
    $module =  (Get-ChildItem -Path $tempMigratePath -Recurse | Where-Object { $_.Name -eq "Af.Forms.Tools.Fls.DataBaseMigrator.dll" })

    if(!$module)
    {
        Write-Host "Could not find Af.Forms.Tools.Fls.DataBaseMigrator.dll" -ForegroundColor Red
    }

    $psModelInfo = Import-Module $module.FullName  -PassThru

    $result =  Update-MigrationToLatest -ConnectionString $connectionString.'#text' -FormType $formType

	Write-Host "Migration result: " + @result -ForegroundColor Green

    Remove-Module "Af.Forms.Tools.Fls.DataBaseMigrator" -Force
}
catch [System.Net.WebException],[System.Exception]
{
	Write-Host "Unhandled exception in UpgradeFas script" -ForegroundColor Red
	Write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red | Tee-Object -FilePath ./errorLog.txt 
}
finally
{
    # Start SitComm service
    Write-Host "Starting SitComm..." -ForegroundColor Green
	if ($sitComm) 
	{	
		Start-Service SitCommWindowsService 
	}
}