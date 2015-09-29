#
# Upgrade Rdm installation
#

$formType = "Rdm"
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
#$scriptPath = "C:\Program Files (x86)\FormFlex System"

#Create paths to temporary folders
$tempFormTypePath = Join-Path $scriptPath -ChildPath "$($formType)TempFolder"

#Check if this path exists if yes remove it and create a new one
if( Test-Path -Path $tempFormTypePath)
{
    Remove-Item -Path $tempFormTypePath -Recurse -Force
}

#Create temporary folders
$tempFormTypeFolder = New-Item -ItemType Directory -Path $tempFormTypePath

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
    # Unpack artifact
   
    Write-Host "Unzipping artifact..." -ForegroundColor Green

    $zip = $shell.NameSpace($zipPath)

    foreach( $item in $zip.Items())
    {
         $shell.Namespace($tempFormTypeFolder.FullName).copyhere($item)
    }

    . "$scriptPath\Initialize-SqlPsEnvironment.ps1"

    # Save current location to return to
    Push-Location

    # Find the sql file to execute
    $sqlFile = Get-ChildItem -Path $tempFormTypePath -Include "*.sql" -Recurse | Select-Object -First 1

    if(!$sqlFile)
    {
       Write-Host "Could not find sql file to execute" -ForegroundColor Red
       return;
    }

    # Navigate to database where the script will be executed
    Set-Location -Path "SQLSERVER:\SQL\$env:COMPUTERNAME\DEFAULT\DATABASES\MDS"
    
    $result = Invoke-Sqlcmd -InputFile  $sqlFile.FullName -SuppressProviderContextWarning

    # Return to previous location
    Pop-Location
}
catch [System.Net.WebException],[System.Exception]
{
	Write-Host "Unhandled exception in UpgradeRdm script" -ForegroundColor Red
	Write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red | Tee-Object -FilePath ./errorLog.txt 
}
finally
{
}