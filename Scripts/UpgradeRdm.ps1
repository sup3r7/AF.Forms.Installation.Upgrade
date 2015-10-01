#
# Upgrade Rdm installation
#

$formType = "Rdm"

$Global:tempFilePath = "./$($formType)tempLogFile.txt"

if(Test-Path -Path $Global:tempFilePath)
{
   Remove-Item -Path $Global:tempFilePath -Force -ErrorAction SilentlyContinue
}

New-Item -Path $Global:tempFilePath -ItemType File

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
    Write-Output "Info: Could not find any zip file" | Out-file $Global:tempFilePath -Append
    
    Break;
}

try
{
    # Unpack artifact
   
    Write-Output "Info: Unzipping artifact..." | Out-file $Global:tempFilePath -Append

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
        Write-Output "Error: Could not find sql file to execute" | Out-file $Global:tempFilePath -Append
       
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
    Write-Output "Error: Unhandled exception in UpgradeRdm script" | Out-file $Global:tempFilePath -Append
    Write-Output "Error: Exception Type: $($_.Exception.GetType().FullName)" | Out-file $Global:tempFilePath -Append
    Write-Output "Error: Exception Message: $($_.Exception.Message)" | Out-file $Global:tempFilePath -Append
}
finally
{
}