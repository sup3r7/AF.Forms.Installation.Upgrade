#
# Upgrade Lab installation
#

$formType = "LabClient"

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
    Write-Host "" -ForegroundColor Red
    Write-Output "Info: Could not find any zip file..." | Out-file $Global:tempFilePath -Append 
    
    Break;
}

try
{
    #
    # Unpack artifact
    #
    Write-Output "Info: Unzipping artifact..." | Out-file $Global:tempFilePath -Append 

    $zip = $shell.NameSpace($zipPath)

    foreach( $item in $zip.Items())
    {
        $childPath = Split-Path $item.Path -Leaf
    
        # Lab
        if( $childPath -eq $formType)
        {
            $shell.Namespace($tempFormTypeFolder.FullName).copyhere($item)
        }
    }

    #
    # Replacing client files
    #
    $formPartTempFullPath = Join-Path $tempFormTypeFolder.FullName -ChildPath "$formType\"

    # Replacing Lab Client files files
    Write-Output "Info: Replacing Lab Client files..." | Out-file $Global:tempFilePath -Append 
    
    $labClientPath =  Join-Path $scriptPath "LabClient\"
    
    $itemsToRemove = Get-ChildItem $labClientPath -Directory
                           
    $itemsToRemove | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                           
    # The -Container switch will preserve the folder structure, The -Recurse switch will go through all folders..wait for it....recursively  
    Copy-Item  "$(Join-Path $tempFormTypeFolder "\LabClient")\*" -Destination "$($labClientPath)\" -Container -Recurse

    return (Get-Content $Global:tempFilePath )
}
catch [System.Net.WebException],[System.Exception]
{
    Write-Output "Error: Unhandled exception in UpgradeLab script" | Out-file $Global:tempFilePath -Append
    Write-Output "Error: Exception Type: $($_.Exception.GetType().FullName)" | Out-file $Global:tempFilePath -Append
    Write-Output "Error: Exception Message: $($_.Exception.Message)" | Out-file $Global:tempFilePath -Append

    
    return (Get-Content $Global:tempFilePath )
}
finally
{
}