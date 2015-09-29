   <#
   .Synopsis
      Short description
   .DESCRIPTION
      Long description
   .EXAMPLE
      Example of how to use this cmdlet
   .EXAMPLE
      Another example of how to use this cmdlet
   #>
   function Initialize-Controls
   {
       [CmdletBinding()]
       Param
       (
           # Param1 help description
            [Parameter(Mandatory=$true,
                      ValueFromPipeline = $true,
                      ValueFromPipelineByPropertyName=$true,
                      Position=0)]
            $Environment,
   
           # Param2 help description
            [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=1)]
            [System.Xml.XmlDocument]
            $Xaml,

           [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=2)]
            [System.Windows.Window]
            $Window,

        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=3)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$ScriptPath
       )
   
       Begin
       {
       }
       Process
       {
           $Script:rootPath = split-path -parent $ScriptPath;

           # Import upgrade module
	        Write-Host "Loading script module..." -ForegroundColor Green
            Import-Module "$Script:rootPath\Modules\UpgradeFormFlex.psm1";
           

            ($Xaml.SelectNodes("//@x:Name", $Script:ns)).'#text' | Where-Object -FilterScript {$_ -Like "$($Environment)_*" }  | ForEach-Object { if([string]::IsNullOrEmpty($_)){continue }; Set-Variable -Name ($_) -Value $window.FindName($_) -Scope Global }
    
        
            $server_combobox =  (Get-Variable "$($Environment)_server_combobox" -ValueOnly)
            $runAll_button =  (Get-Variable "$($Environment)_runAll_button" -ValueOnly)
            $runScript_button =  (Get-Variable "$($Environment)_runScript_button" -ValueOnly)
            $include_toggle =  (Get-Variable "$($Environment)_include_toggle" -ValueOnly)

            $Script:upgradeConfig.Servers| Where-Object -FilterScript  { $_.Environment -eq $Environment } | ForEach-Object { $server_combobox.items.Add($_) | Out-Null }
            
            if($server_combobox.items.Count -gt 0)
            {
                $server_combobox.SelectedIndex = 1;
                $server_combobox.DisplayMemberPath = "Name"
                
               
            }

            $Script:TestWindow = $Window;          
            $Script:artifactFiles = Get-ArtifactFiles $Script:rootPath

                   # Exit script if no artifact was found
            if ($Script:artifactFiles.Count -lt 1)
            {
                return
            }


            $server_combobox.Add_SelectionChanged({

                $currentEnvironment = [string]::Empty;
                

                if( !($this.Name -match '^[^_]+(?=_)'))
                {
                  return 
                }

                $currentEnvironment = $Matches.Values[0]

                $server_combobox =  (Get-Variable "$($currentEnvironment)_server_combobox" -ValueOnly)
 
                (Get-Variable "$($currentEnvironment)_IPAdress_value_label" -ValueOnly).Content = $server_combobox.SelectedItem.IPAddress
                (Get-Variable "$($currentEnvironment)_formflextpart_value_label" -ValueOnly).Content = $server_combobox.SelectedItem.FormFlexPart
                (Get-Variable "$($currentEnvironment)_include_toggle" -ValueOnly).IsChecked = $server_combobox.SelectedItem.IncludedInUpdate
                (Get-Variable "$($currentEnvironment)_packageName_value_label" -ValueOnly).Content = $server_combobox.SelectedItem.PackageName

            })


            $runAll_button.add_click({
            
                    $Script:upgradeConfig.Servers | ForEach-Object { 
    
                    $_ | Update-Server -sourceIPAddress $Script:upgradeConfig.SourceIPAddress -artifactFile $Script:artifactFiles[$_.PackageName].FilePath 

            }
            
            })

            
            $runScript_button.add_click({


                $currentEnvironment = [string]::Empty;
                

                if( !($this.Name -match '^[^_]+(?=_)'))
                {
                  return 
                }

                $currentEnvironment = $Matches.Values[0]

                $server_combobox =  (Get-Variable "$($currentEnvironment)_server_combobox" -ValueOnly)

                Update-Server -Server $server_combobox.SelectedItem -sourceIPAddress $Script:upgradeConfig.SourceIPAddress -artifactFile $Script:artifactFiles[$server_combobox.SelectedItem.PackageName].FilePath 

            
            })

             $include_toggle.add_checked({
            

                $currentEnvironment = [string]::Empty;
                

                if( !($this.Name -match '^[^_]+(?=_)'))
                {
                  return 
                }

                $currentEnvironment = $Matches.Values[0]

                $server_combobox =  (Get-Variable "$($currentEnvironment)_server_combobox" -ValueOnly)

                $index =  $Script:upgradeConfig.Servers.IndexOf($server_combobox.SelectedItem)
                $Script:upgradeConfig.Servers[$index].IncludedInUpdate = $true;
                $Script:upgradeConfig |  ConvertTo-Json | Set-Content "$Script:rootPath\Config\Config.json" -Force  

            })

            
              $include_toggle.add_unchecked({


              
                $currentEnvironment = [string]::Empty;
                

                if( !($this.Name -match '^[^_]+(?=_)'))
                {
                  return 
                }

                $currentEnvironment = $Matches.Values[0]

                $server_combobox =  (Get-Variable "$($currentEnvironment)_server_combobox" -ValueOnly)
               
                $index =  $Script:upgradeConfig.Servers.IndexOf($server_combobox.SelectedItem)
                $Script:upgradeConfig.Servers[$index].IncludedInUpdate = $false;
                $Script:upgradeConfig |  ConvertTo-Json | Set-Content "$Script:rootPath\Config\Config.json" -Force
           
 })

             if($server_combobox.items.Count -gt 0)
             {
                $server_combobox.SelectedIndex = 1;
               # (Get-Variable "$($Environment)_Info_TextBlock" -ValueOnly).Text =("Selected Item: {0}" -f $server_combobox.SelectedItem.Name)
                (Get-Variable "$($Environment)_IPAdress_value_label" -ValueOnly).Content = $server_combobox.SelectedItem.IPAddress
                (Get-Variable "$($Environment)_formflextpart_value_label" -ValueOnly).Content = $server_combobox.SelectedItem.FormFlexPart
                (Get-Variable "$($Environment)_include_toggle" -ValueOnly).IsChecked = $server_combobox.SelectedItem.IncludedInUpdate
                (Get-Variable "$($Environment)_packageName_value_label" -ValueOnly).Content = $server_combobox.SelectedItem.PackageName
               
             }

             Start-LogFileListener -LogFilePath "D:\Powershell Script\AF.Forms.Installation.Upgrade\Log\" -Environment $Environment

       }
       End
       {
       }
   }
    
 Function Setup-Controls {

 [CmdletBinding()]

    Param(

        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$XamlPath = "D:\Powershell Script\AF.Forms.Installation.Upgrade\Views\MainWindow.xaml" , 

        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=1)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$ScriptPath
    )
     
    Begin
    {
    }
    Process
    {

       try
       {
            [xml]$xaml = Get-Content -Path $XamlPath
            $stream = New-Object -TypeName System.IO.StreamReader($XamlPath);
            $reader = [System.Xml.XmlNodeReader]::Create($stream)
            $window = [Windows.Markup.XamlReader]::Load($reader)
            $Script:ns = New-Object System.Xml.XmlNamespaceManager($xaml.NameTable)
            $Script:ns.AddNamespace("x", $xaml.DocumentElement.x)
            $Script:rootPath = split-path -parent $ScriptPath;
            $script:stopped = $false;
            Import-Module "$rootPath\Modules\UpgradeFormFlex.psm1";

            # Get config file
            $Script:upgradeConfig= Get-UpgradeConfig "$rootPath\Config\Config.json";
            
            $Script:environmentList = $Script:upgradeConfig.Servers | Select-Object -Property Environment -Unique 

            ($Script:environmentList).environment | Initialize-Controls -Xaml $xaml -Window $window -ScriptPath $ScriptPath

            $window.add_closing({
           
             ($Script:environmentList).environment |  Stop-LogFileListener -LogFilePath "D:\Powershell Script\AF.Forms.Installation.Upgrade\Log\logfile.txt"
            
            })

            $window.add_loaded({
            

            })

            $window.ShowDialog() | Out-Null

        
       }

       catch [System.Exception]
       {
           Write-Output $_ | Out-File $Global:tempFilePath;
       }
       finally
       {
                  ($xaml.SelectNodes("//@x:Name", $ns)).'#text' |  ForEach-Object { if([string]::IsNullOrEmpty($_)){continue }; Remove-Variable -Name ($_) -ErrorAction SilentlyContinue -Scope Global }
       }
    }

   }


   <#
   .Synopsis
      Short description
   .DESCRIPTION
      Long description
   .EXAMPLE
      Example of how to use this cmdlet
   .EXAMPLE
      Another example of how to use this cmdlet
   #>
   function Start-LogFileListener
   {
       [CmdletBinding()]
       [Alias()]
       [OutputType([int])]
       Param
       (
            [Parameter(Mandatory=$true,
                      ValueFromPipelineByPropertyName=$true,
                      Position=0)]
            [ValidateScript( { Test-Path -Path $_ })]
            $LogFilePath,
   
            [Parameter(Mandatory=$false,
                      ValueFromPipelineByPropertyName=$false,
                      Position=1)]
            [string]
            $SourceIdentifier = "LogfileModification",

            [Parameter(Mandatory=$false,
            Position=2)]
            [int]
            $interval= 5,

            [Parameter(Mandatory=$false,
                       ValueFromPipelineByPropertyName=$true,
                       ValueFromPipeline = $true,
                       Position=3)]
            [string]
            $Environment
       )
   
       Begin
       {
            
       }
       Process
       {
           
            $tempLogFileName = 'templogfile.txt'
           
            $Global:tempFilePath =  Join-Path -Path $LogFilePath -ChildPath $tempLogFileName
           
            if(Test-Path -Path $tempFilePath )
            {
                Remove-Item $Global:tempFilePath -Force
            }

            New-Item -ItemType File -Name $tempLogFileName -Path $LogFilePath | Out-Null

            $LogFilePathExtraSlash = $Global:tempFilePath -replace "\\", "\\" 

            $queryChanged = @"
                        SELECT * FROM __InstanceModificationEvent 
                        WITHIN $interval 
                        WHERE TargetInstance ISA 'CIM_DataFile' 
                        and  TargetInstance.Name='$LogFilePathExtraSlash'
                        and TargetInstance.lastmodified <> previousinstance.lastmodified
"@
 
    $WmiChanged = @{
                        Query = "$queryChanged";
    
                        Action ={
                                    $Global:Data = $Event;
                                    
                                    $logFileContent = (Get-Content $Global:tempFilePath -Raw)
                                    $test_Info_TextBlock.Text = $logFileContent
                                    $production_Info_TextBlock.Text = $logFileContent
                                };
    
                        SourceIdentifier = ("{0}{1}" -f $Environment, $SourceIdentifier)
    
                    }


                    Register-WmiEvent @WmiChanged | Out-Null


       }

       End
       {
       }
   }


   <#
   .Synopsis
      Short description
   .DESCRIPTION
      Long description
   .EXAMPLE
      Example of how to use this cmdlet
   .EXAMPLE
      Another example of how to use this cmdlet
   #>
   function Stop-LogFileListener
   {
       [CmdletBinding()]
       [Alias()]
       [OutputType([int])]
       Param
       (
           [Parameter(Mandatory=$false,
                      ValueFromPipelineByPropertyName=$false,
                      Position=0)]
           [string]
           $SourceIdentifier= "LogfileModification",

            [Parameter(Mandatory=$false,
                      Position=1)]
            [ValidateScript( { Test-Path -Path $_ })]
            $LogFilePath,

            
            [Parameter(Mandatory=$false,
                       ValueFromPipelineByPropertyName=$true,
                       ValueFromPipeline = $true,
                       Position=2)]
            [string]
            $Environment
       )
   
       Process
       {
                Unregister-Event -SourceIdentifier ("{0}{1}" -f $Environment, $SourceIdentifier) 

                Add-Content -Path $LogFilePath -Value (Get-Content $Global:tempFilePath -raw) 

        }
   }
