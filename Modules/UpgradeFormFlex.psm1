
<#
.Synopsis
   Get config file with information about servers etc
.DESCRIPTION
   Long description
.EXAMPLE
   Get-UpgradeConfig .\ServersToUpgrade.json
#>
function Get-UpgradeConfig
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        # Path to config file
        [Parameter(Mandatory=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_})]
        [string]
        $Path
    )

    Begin
    {
	  Write-LogMessage -Message "Loading configuration" -ErrorType Info | Write-Output | Out-file $Global:tempFilePath -Append
    }
    Process
    {
        try
        {
			
            # Get config file with servers to upgrade
            $configFile = Get-Content $Path -Raw

            # Abort if no config file
            if ([string]::IsNullOrEmpty($configFile)){
                Write-LogMessage -Message "Could not find config file! Script is aborted!" -ErrorType Error | Write-Output | Out-File -FilePath $Global:tempFilePath -Append
                return;
            }

            # Convert to object
            $config = ConvertFrom-Json $configFile;

            # Return
            return $config;

        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-LogMessage -Message "Unhandled exception in Get-UpgradeConfig"  -ErrorType Error  | Write-OUtput | Out-file -FilePath $Global:tempFilePath -Append
        }
        finally
        {
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
function Get-ArtifactFile
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   
                   Position=0)]
        $Path,

        [Parameter(Mandatory=$true,
                   
                   Position=1)]
        $Regex
    )

    Process
    {
    
        try
        {
        
            $foundArtifact =   Get-ChildItem -Path $Path -Include "*.zip" -Recurse | ForEach-Object { 
										
                                        if( ($_.FullName -Match $Regex ))
										{ 
											return @{ FilePath = $_.Name; BuildCount = [int]$Matches.buildcounter; } 
										}
								   } | Sort-Object { $_.BuildCount } -Descending  | Select-Object -First 1


    	    if ($foundArtifact -eq $null)
		    {
               Write-LogMessage -Message "No artifact found in path Please add artifact and run script again" -ErrorType Error | Write-Output | Out-File -FilePath $Global:tempFilePath -Append
    	    }

            return $foundArtifact
      
        }
        catch [System.Net.WebException],[System.Exception]
        {
          Write-LogMessage -Message "Unhandled exception in Get-ArtifactFile" -ErrorType Error | Write-Output | Out-File -FilePath $Global:tempFilePath -Append
        }
        finally
        {
        } 
    }
}

<#
.Synopsis
   Get latest artifact file
.DESCRIPTION
   Long description
.EXAMPLE
   Get-ArtifactFile 
.INPUTS
   Script execution path
#>
function Get-ArtifactFiles
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    Param
    (
        [Parameter(Mandatory=$true,
                   Position=0)]
        [ValidateScript({Test-Path $_})]
        [string]
        $Path
    )

    Process
    {
	    try
        {
           $foundArtifacts = @{};

           Write-LogMessage -Message "Searching for the latest artifact files..." -ErrorType Info | Write-Output | Out-File -FilePath $Global:tempFilePath -Append

           $foundArtifact = Get-ArtifactFile -Path $Path -Regex "(?<packagename>\w+)_svn_(?<buildvcsnumber>\d+)_\w{1,1}\.(?<buildcounter>\d+)"

           $foundArtifacts.Add("NightlyBuild", $foundArtifact);
           
           $foundArtifact = Get-ArtifactFile -Path $Path -Regex "(?<packagename>RDM_Upgrade)_Svn_(?<buildcounter>\d+)"
            
           $foundArtifacts.Add("Reports", $foundArtifact);

		   return $foundArtifacts
        }
        catch [System.Net.WebException],[System.Exception]
        {
           Write-LogMessage -Message "Unhandled exception in Get-ArtifactFile" -ErrorType Error | Write-Output | Out-File -FilePath $Global:tempFilePath -Append
        }
        finally
        {
        }
    }
}

<#
.Synopsis
   Upgrade one unique server
.DESCRIPTION
   Long description
.EXAMPLE
   
#>
function Update-Server
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        # The server object specified in config file
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [PSObject]
        $Server,
		# The source IP address
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$false,
                   ValueFromPipelineByPropertyName=$false,
                   Position=1)]
        [string]
        $SourceIPAddress,
		# The artifact file
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$false,
                   ValueFromPipelineByPropertyName=$false,
                   Position=2)]
        [string]
        $ArtifactFile
    )

    Process
    {
		try
        {
			# Return if server is not to be updated
			if ($Server.IncludedInUpdate){
			
                Write-LogMessage "Updating server - $($Server.Name) - $($Server.FormFlexpart)..." -Environment $Server.Environment -ErrorType Verbose | Write-Output | Out-File $Global:tempFilePath -Append
			}
			else
			{
				Write-LogMessage "$($Server.Name) - $($Server.FormFlexpart) -  is not set to be updated!" -Environment $Server.Environment -ErrorType Error | Write-Output | Out-File $Global:tempFilePath -Append
				return
			}

			$InstallationPath = $Server.InstallPath.Trim()
			$FormFlexPart = $Server.FormFlexPart.Trim()
			$DestinationIpAddress = $Server.IPAddress.Trim()
          
            $Domain = [string]::Empty

            if(![string]::IsNullOrEmpty($Server.Domain ))
            {
              $Domain = $Server.Domain
            }
            else
            {
              $Domain = $DestinationIpAddress
            }

            if( ![string]::IsNullOrEmpty($Server.UserName) -and ![string]::IsNullOrEmpty($Server.Password))
            {
                $RemoteUser = "$Domain\$($server.UserName)"
			    $RemotePWord = ConvertTo-SecureString -String $server.Password -AsPlainText -Force
			    $RemoteCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $RemoteUser, $RemotePWord

            }
            elseif( ![string]::IsNullOrEmpty($Server.UserName) -and [string]::IsNullOrEmpty($Server.Password))
            {
            
                $RemoteUser = "$Domain\$($server.UserName)"
                $RemoteCredential = Get-Credential -UserName $RemoteUser -Message  ("Please enter your username and password for {0}" -f $server.Name)

            }
            else
            {
			  $RemoteCredential = Get-Credential -Message ("Please enter your username and password for {0}" -f $server.Name)
            }
	        
            if(!$RemoteCredential)
            {
                Write-LogMessage "You didn't enterad valid credentials" -ErrorType Error -Environment $Server.Environment | Out-File -FilePath $Global:tempFilePath -Append
                return
            }

			$Session = New-PSSession -ComputerName $DestinationIpAddress.Trim() -Credential $RemoteCredential

            #
            # Everything in this ScriptBlock is executed on the remote server
			#
            Invoke-Command  -Session $session -ScriptBlock {

			   param ($installationPath, $formFlexPart, $sourceIpAddress, $upgradePackage, $localCredential, $artifactFile)

                Set-PSBreakpoint -Variable Test

               
				#Write-LogMessage "Mapping source file location..." -ErrorType Verbose -Environment $using:Server.Environment | Out-File -FilePath $Global:tempFilePath
				New-PSDrive -Name I -PSProvider FileSystem -Root \\$sourceIpAddress\Install -Credential $localCredential

				#Write-LogMessage "Removing old installation files..." 
				Remove-Item "$installationPath\MigrateTempFolder" -Recurse -ErrorAction SilentlyContinue
				Get-ChildItem "$installationPath\" -Include *.ps1,*.zip -Recurse | Remove-Item

				#Write-LogMessage "Copying new installation files..." | Out-File -FilePath $Global:tempFilePath -Append
				Copy-Item -Path "I:\$artifactFile" -Destination $installationPath
				switch ($formFlexPart)
				{
					"Fas" { Copy-Item -Path "I:\Scripts\UpgradeFas.ps1" -Destination $installationPath; Break }
					"Fls" { Copy-Item -Path "I:\Scripts\UpgradeFls.ps1" -Destination $installationPath; Break }
					"Lab" { Copy-Item -Path "I:\Scripts\UpgradeLab.ps1" -Destination $installationPath; Break }
                    "Etl" { Copy-Item -Path "I:\Scripts\MoveEtl.ps1"    -Destination $installationPath; Break }
                    "Rdm" { Copy-Item -Path "I:\Scripts\UpgradeRdm.ps1" -Destination $installationPath;
                            Copy-Item -Path "I:\Scripts\Initialize-SqlPsEnvironment.ps1" -Destination $installationPath; Break }
				}

                 $Test = "break here"

				# Run upgrade script
				#Write-LogMessage "Updating files..." | Out-File -FilePath $Global:tempFilePath -Append

				switch ($formFlexPart)
				{
					"Fas" { . "$installationPath\UpgradeFas.ps1"; Break }
					"Fls" { . "$installationPath\UpgradeFls.ps1"; Break }
					"Lab" { . "$installationPath\UpgradeLab.ps1"; Break }
                    "Etl" { . "$installationPath\MoveEtl.ps1";    Break }
                    "Rdm" { . "$installationPath\UpgradeRdm.ps1"; Break }
                    
				}

				#Write-LogMessage "Unmapping source file location..." | Out-File -FilePath $Global:tempFilePath -Append
                
				Remove-PSDrive -Name I

			} -ArgumentList $InstallationPath, $FormFlexPart, $SourceIpAddress, $UpgradePackage, $RemoteCredential, $ArtifactFile

			#Remove-PSSession -Session $Session
        }
        catch [System.Net.WebException],[System.Exception]
        {
            Write-LogMessage -Message $_ -ErrorType Error | Write-Output | Out-File -FilePath $Global:tempFilePath -Append
        }
        finally
        {
          
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
            ($Xaml.SelectNodes("//@x:Name", $Script:ns)).'#text' | Where-Object -FilterScript {$_ -Like "$($Environment)_*" }  | ForEach-Object { if([string]::IsNullOrEmpty($_)){continue }; Set-Variable -Name ($_) -Value $window.FindName($_) -Scope Global }
           
            $Script:rootPath = split-path -parent $ScriptPath;

           # Import upgrade module
            Write-LogMessage -Message "Loading script module..." -Environment $Environment -ErrorType Info | Write-Output | Out-File -FilePath $Global:tempFilePath
            
            Import-Module "$Script:rootPath\Modules\UpgradeFormFlex.psm1";
           

    
        
            $server_combobox =  (Get-Variable "$($Environment)_server_combobox" -ValueOnly)
            $runAll_button =  (Get-Variable "$($Environment)_runAll_button" -ValueOnly)
            $runScript_button =  (Get-Variable "$($Environment)_runScript_button" -ValueOnly)
            $include_toggle =  (Get-Variable "$($Environment)_include_toggle" -ValueOnly)
            $clear_button =  (Get-Variable "$($Environment)_clear_button" -ValueOnly)
            
            $Script:upgradeConfig.Servers| Where-Object -FilterScript  { $_.Environment -eq $Environment } | ForEach-Object { $server_combobox.items.Add($_) | Out-Null }
            
            if($server_combobox.items.Count -gt 0)
            {
                $server_combobox.SelectedIndex = 1;
                $server_combobox.DisplayMemberPath = "Name"
                
               
            }

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


            $clear_button.add_click({
            
                 $currentEnvironment = [string]::Empty;
                

                if( !($this.Name -match '^[^_]+(?=_)'))
                {
                  return 
                }

                $currentEnvironment = $Matches.Values[0]

                (Get-Variable "$($currentEnvironment)_Info_TextBlock" -ValueOnly).Text = ([string]::Empty)
            
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
                (Get-Variable "$($Environment)_IPAdress_value_label" -ValueOnly).Content = $server_combobox.SelectedItem.IPAddress
                (Get-Variable "$($Environment)_formflextpart_value_label" -ValueOnly).Content = $server_combobox.SelectedItem.FormFlexPart
                (Get-Variable "$($Environment)_include_toggle" -ValueOnly).IsChecked = $server_combobox.SelectedItem.IncludedInUpdate
                (Get-Variable "$($Environment)_packageName_value_label" -ValueOnly).Content = $server_combobox.SelectedItem.PackageName
               
             }
       }
       End
       {
       }
   }
    
 Function Start-UpgradeWindow {

 [CmdletBinding()]

    Param(

        [Parameter(Mandatory=$false,ValueFromPipelineByPropertyName=$true,Position=0)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$XamlPath = "D:\Powershell Script\AF.Forms.Installation.Upgrade\Views\MainWindow.xaml" , 

        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=1)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$ScriptPath,

        [Parameter(Mandatory=$true,Position=2)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]
        $LogFilePath
    )
     
    Begin
    {
    }
    Process
    {

       try
       {


            Add-Type -Assembly PresentationFramework            
            Add-Type -Assembly PresentationCore 

            [xml]$xaml = Get-Content -Path $XamlPath
            $stream = New-Object -TypeName System.IO.StreamReader($XamlPath)
            $reader = [System.Xml.XmlNodeReader]::Create($stream)
            $window = [Windows.Markup.XamlReader]::Load($reader)
            $Script:ns = New-Object System.Xml.XmlNamespaceManager($xaml.NameTable)
            $Script:ns.AddNamespace("x", $xaml.DocumentElement.x)
            $Script:rootPath = split-path -parent $ScriptPath;
            $script:stopped = $false;
            $Global:LogfilePath = $LogfilePath
            $tempLogFileName = 'templogfile.txt'
            $logFilePathParenFolder = Split-Path -Path $LogFilePath -Parent
            $Global:tempFilePath =  Join-Path -Path $logFilePathParenFolder -ChildPath $tempLogFileName
           
            if(Test-Path -Path $Global:tempFilePath )
            {
                Remove-Item $Global:tempFilePath -Force
            }

            New-Item -ItemType File -Name $tempLogFileName -Path $logFilePathParenFolder | Out-Null


            # Get config file
            $Script:upgradeConfig= Get-UpgradeConfig "$rootPath\Config\Config.json";
            
            $Script:environmentList = $Script:upgradeConfig.Servers | Select-Object -Property Environment -Unique 

            ($Script:environmentList).environment | Initialize-Controls -Xaml $xaml -Window $window -ScriptPath $ScriptPath

            $window.add_closing({
           
                Add-Content -Path $Global:LogFilePath -Value (Get-Content $Global:tempFilePath -raw) 
            })

            $window.add_loaded({

      
            })


            $window.ShowDialog() | Out-Null

        
       }

       catch [System.Exception]
       {
         Write-LogMessage -Message $_ -ErrorType Error |  Write-Output | Out-File $Global:tempFilePath -Append;
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
            $interval= 1,

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
                                    $test_Info_TextBlock.Dispatcher.Invoke( { $test_Info_TextBlock.Text = $logFileContent})
                                    $production_Info_TextBlock.Dispatcher.Invoke( { $production_Info_TextBlock.Text = $logFileContent})
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
                       ValueFromPipelineByPropertyName=$true,
                       ValueFromPipeline = $true,
                       Position=0)]
            [string]
            $Environment,
           [Parameter(Mandatory=$false,
                      ValueFromPipelineByPropertyName=$false,
                      Position=1)]
           [string]
           $SourceIdentifier= "LogfileModification"


       )
   
       Process
       {
            try
            {
                Unregister-Event -SourceIdentifier ("{0}{1}" -f $Environment, $SourceIdentifier) 

                Add-Content -Path $Global:LogFilePath -Value (Get-Content $Global:tempFilePath -raw) 
            }
            catch [System.Exception]
            {
              Write-LogMessage -Message $_ -Environment $Environment -ErrorType Error  |  Write-Output | out-file $Global:tempFilePath -Append
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
   function Write-LogMessage
   {
       [CmdletBinding()]
       [Alias()]
       [OutputType([String])]
       Param
       (
           [Parameter(Mandatory=$true,
                      ValueFromPipelineByPropertyName=$true,
                      Position=0)]
           [ValidateNotNullOrEmpty()]
           [string]$Message,
           [Parameter(Mandatory=$false, Position=1)]
           [String]$Environment,

           [Parameter(Mandatory=$false,Position=2)]
           [ValidateSet("Error","Info","Warning","Verbose")]
           [string]$ErrorType
   
       )
   
       Process
       {
            
            if($ErrorType)
            {
               $Message = "{0}: {1}" -f $ErrorType, $Message 
            }
            
            if(![string]::IsNullOrEmpty($Environment))
            {
            
                $Run = Set-Message -Environment $Environment -Message $Message
                
                return $Run.Text;
            
            }

           ($Script:environmentList).environment | Set-Message -Message $Message -OutVariable Run

            return $Run.Text;   
            
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
   function Set-Message
   {
       [CmdletBinding()]
       [Alias()]
       [OutputType([System.Windows.Documents.Run])]
       Param
       (
           [Parameter(Mandatory=$true,
                      ValueFromPipelineByPropertyName=$true,
                      Position=0)]
           [ValidateNotNullOrEmpty()]
           [string]$Message,
           [Parameter(Mandatory=$false,                      
                        ValueFromPipeline = $true,
                        ValueFromPipelineByPropertyName=$true,
                        Position=1)]
           [String]$Environment
       )
   
       Begin
       {
       }
       Process
       {

            $timeStamp = Get-Date -DisplayHint DateTime
            $Run = New-Object System.Windows.Documents.Run
            $Run.Text = ("{0}: {1}" -f $timeStamp,$Message)

            Switch -regex ($Message) {
            
            "^Verbose" {
                            $Run.Foreground = "Orange"
                       }
            "^Warning" {
                            $Run.Foreground = "Blue"
                       }
            "^Info"    {
                            $Run.Foreground = "Black"
                       }
            "^Error"   {
                            $Run.Foreground = "Red"
                       }
}

            $infoTextBlock = (Get-Variable "$($Environment)_Info_TextBlock" -ValueOnly -ErrorAction SilentlyContinue)
            $scrollViewer = (Get-Variable "$($Environment)_ScrollViewer" -ValueOnly -ErrorAction SilentlyContinue)

           
            if(!$infoTextBlock)
            {
                return
            }

            $window.Dispatcher.Invoke( { 
                
                $infoTextBlock.Inlines.Add((New-Object System.Windows.Documents.LineBreak))
                $infoTextBlock.Inlines.Add($Run)
                $scrollViewer.ScrollToBottom()

                
                
                })

           return $Run
       }
       End
       {
       }
   }