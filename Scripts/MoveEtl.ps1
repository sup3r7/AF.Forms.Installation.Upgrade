#
# Upgrade Rdm installation
#

$formType = "Etl"
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


    # Find the sql file to execute
    $dtsxFile = Get-ChildItem -Path $tempFormTypePath -Include "*.dtsx" -Recurse | Select-Object -First 1

    if(!$dtsxFile)
    {
       Write-Host "Could not find dtsx file to move " -ForegroundColor Red
       return;
    }

     Move-Item -Path $dtsxFile.FullName -Destination "E:\Install\" -Force

}
catch [System.Net.WebException],[System.Exception]
{
	Write-Host "Unhandled exception in MoveEtl script" -ForegroundColor Red
	Write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red | Tee-Object -FilePath ./errorLog.txt 
}
finally
{
}