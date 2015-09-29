#Requires –Version 4.0

Write-Host "Starting update..." -ForegroundColor Yellow

#Check if user or machine is authorized to execute scripts
$exLevel = Get-ExecutionPolicy

$xmlName = "web.config"

if( $exLevel -eq [Microsoft.PowerShell.ExecutionPolicy]::Restricted)
{
    Write-Host "You are not allowed to execute the script. Please contact your administrator" -ForegroundColor Red
}

# Get the formtype type from the passed in argument
$formType = $args[0]

if([string]::IsNullOrEmpty($formType))
{
    Write-Host "FormType could not be determined" -ForegroundColor Red
    Break;
}

#Path where this script is executed from
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
    Write-Host -ForegroundColor Yellow "Could not find any zip file"
    Break;
}


try
{
    $zip = $shell.NameSpace($zipPath)

    foreach( $item in $zip.Items())
    {
        $childPath = Split-Path $item.Path -Leaf
    
        if( $childPath -eq $formType)
        {
            $shell.Namespace($tempFormTypeFolder.FullName).copyhere($item)
        }

        if( $childPath -eq "Migrator")
        {
            $shell.Namespace($tempMigrateFolder.FullName).copyhere($item)

            New-ModuleManifest -Path "$tempMigratePath\$childPath\Af.Forms.Tools.Fls.DataBaseMigrator.psd1" -Author "Fabio Ostlind" -CompanyName "AF Industry AB" -RequiredAssemblies (Get-ChildItem -Path $tempMigratePath -Recurse -Include "*.dll")
        }
    }

    $targetDirectories = Get-ChildItem -Path (Join-Path -Path $scriptPath -ChildPath $formType) -Directory 

    $zipFolderDirectories = Get-ChildItem -Recurse -Path "$tempFormTypeFolder\$formType" -Directory

    $zipFolderDirectories += Get-ChildItem -Recurse -Path "$tempFormTypeFolder" -Directory | Where-Object { $_.Name -eq "Migrator" }

    Write-Host "Copying dll files.." -ForegroundColor Yellow

    foreach( $zipDirectory in $zipFolderDirectories )
    {
            foreach( $targetDirectory in $targetDirectories)
            {
                if( $zipDirectory.Name -eq "Migrator")
                {
                    $migratorModules = Get-ChildItem -Path $zipDirectory.FullName -Recurse -Include "*.dll" 
                    
                    Copy-Item $migratorModules -Destination $scriptPath 
                }

                if( $zipDirectory.Name -eq $targetDirectory.Name)
                {
                    switch($targetDirectory.Name)
                    {
                        "Client" {
                    
                            $clientBinPath = Join-Path $targetDirectory.FullName -ChildPath "ClientBin\"

                            Remove-Item -Path "$clientBinPath\*" -Force 

                            Copy-Item (Get-ChildItem -Path $zipDirectory.FullName -Recurse -Include "*.xap" ) -Destination $clientBinPath -Force
                        
                            continue
                        }

                        "Server" {
                    
                            $serverBinPath = Join-Path $targetDirectory.FullName -ChildPath "Bin\"
                        
                            Remove-Item -Path "$serverBinPath\*" -Force -Include "*.dll" 

                            Copy-Item (Get-ChildItem -Path $zipDirectory.FullName -Recurse -Include "*.dll" ) -Destination $serverBinPath -Force 
                        
                            continue
                        }
                    
                        "WindowsService"{
                    
                            Remove-Item -Path "$($targetDirectory.FullName)\*" -Exclude "*.exe.config","*.exe" -Force 
                           
                            Copy-Item (Get-ChildItem -Path $zipDirectory.FullName -Recurse -Include "*.dll" ) -Destination "$($targetDirectory.FullName)\" -Force

                            Continue
                        }

                        "LabClient"{

                            $LabClient = "$($targetDirectory.FullName)";

                            $itemsToRemove = Get-ChildItem $LabClient -Directory
                           
                            $itemsToRemove | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                           
                            # The -Container switch will preserve the folder structure, The -Recurse switch will go through all folders..wait for it....recursively  
                            
                             Copy-Item  "$($zipDirectory.FullName)\*" -Destination "$($targetDirectory.FullName)\" -Container -Recurse

                            Continue
                            
                        }
                    }
 
                }
            }
    }

    $formTypeDbContext = $formType + "DbContext"

    $xml = [xml](Get-Content "$scriptPath/$formType/Server/$xmlName") 

    $connectionString = (Select-Xml -Xml $xml -XPath "//connectionStrings/add[@name='$formTypeDbContext']/@connectionString").Node

    $module =  (Get-ChildItem -Path $tempMigrateFolder -Recurse | Where-Object { $PSItem.Name -eq "Af.Forms.Tools.Fls.DataBaseMigrator.dll" })

    if( [string]::IsNullOrEmpty($module))
    {
        Write-Host "Could not find Af.Forms.Tools.Fls.DataBaseMigrator.dll" -ForegroundColor Red
    }

    Write-Host "Updating database..." -ForegroundColor Yellow

    $psModelInfo = Import-Module $module.FullName  -PassThru

   $result =  Update-MigrationToLatest -ConnectionString $connectionString.'#text' -FormType $formType

    Write-Host "Updated successfully!" -ForegroundColor Green

    Remove-Module $module.BaseName  

}

catch [System.SystemException]
{

    Write-Host "Update Failed!" -ForegroundColor Red
    Write-host "Caught an exception:" -ForegroundColor Red
    Write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-host "Exception Message: $($_.Exception.Message)" -ForegroundColor Red | Tee-Object -FilePath ./errorLog.txt 
}

finally
{
    if( Test-Path -Path $tempFormTypeFolder.FullName)
    {
        Remove-Item -Path $tempFormTypeFolder.FullName -Recurse -Force
    }
    
     
}









 