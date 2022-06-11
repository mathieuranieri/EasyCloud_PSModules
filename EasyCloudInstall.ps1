Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Function Check-GitInstalled {
    Try {
        $gitversion = git --version
        Write-Host "Git Version found: $gitversion" -ForegroundColor Green
    } 
        
    Catch  {
        Write-Host "Please install Git before installing EasyCloud" -ForegroundColor Red
        Read-Host "Enter to exit"
        Break;
    }
}

Function Check-NodeJSInstalled {
    Try {
        $nodeversion = node -v
        Write-Host "NodeJS Version found: $nodeversion" -ForegroundColor Green
        Write-Host "Starting library installation.." -ForegroundColor Green
        npm i --silent --location=global @angular/cli
        Write-Host "Dependencies installed" -ForegroundColor Green
    } 
        
    Catch  {
        Write-Host "Please install NodeJs before installing EasyCloud" -ForegroundColor Red
        Read-Host "Enter to exit"
        Break;
    }
}

Function Get-InstallFolder {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'EasyCloud Installer'
    $form.Size = New-Object System.Drawing.Size(300,200)
    $form.maximumSize = New-Object System.Drawing.Size(300,200)
    $form.minimumSize = New-Object System.Drawing.Size(300,200)
    $form.StartPosition = 'CenterScreen'
    $form.BackColor = "White"

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(50,120)
    $okButton.Size = New-Object System.Drawing.Size(100,23)
    $okButton.Text = 'Start Installation'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $okButton
    $form.Controls.Add($okButton)

    $image1 = New-Object System.Windows.Forms.pictureBox
    $image1.Location = New-Object Drawing.Point 40,40
    $image1.Size = New-Object System.Drawing.Size(100,100)
    Try {
        $image1.image = [system.drawing.image]::FromFile("./EasyCloudLogo.png")
    } Catch {}
    $form.controls.add($image1)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(160,120)
    $cancelButton.Size = New-Object System.Drawing.Size(75,23)
    $cancelButton.Text = 'Exit'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancelButton
    $form.Controls.Add($cancelButton)

    $form.Topmost = $true
    $result = $form.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK)
    {
        Return Initialize-Install
    } else {
        Write-Host "Installation cancelled"
        Break;
    }
}

Function Initialize-Install {
    Begin {
        Write-Host "App installation will start...`n" -ForegroundColor Yellow
    }

    Process {
        Function Get-Folder($initialDirectory="")
        {
            Add-Type -AssemblyName System.Windows.Forms

            $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
            $FolderBrowser.Description = 'Select the folder containing the data'
            $result = $FolderBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
            
            if ($result -eq [Windows.Forms.DialogResult]::OK){
                $FolderBrowser.SelectedPath
            } else {
                exit
            }

            return $folder
        }

        $folder = Get-Folder

        If ($folder)
        {
            Write-Host "Installing folder structure in: $folder" -ForegroundColor Cyan
            Return $folder
        } Else {
            Write-Warning "Something wrong happened"
            Read-Host "Press enter to exit"
            Break;
        }
    }
}

Function Add-FolderStructure {
    Param(
        [Parameter(Mandatory=$true)]
        $mainPath
    ) 

    Process {
        $foldersToCreate = @(
            'App',
            'Configuration'
        )

        $progressCounter = $foldersToCreate.Length

        $subFoldersToCreate = @(
            @{'App' = 'Modules'},
            @{'App' = 'Modules/VMDeployment'}
            @{'App' = 'Modules/VMConfiguration'}
            @{'App' = 'Modules/VMMonitoring'}
            @{'App' = 'WebInterface'},
            @{'App' = 'BackServer'},
            @{'Configuration' = 'VirtualMachines'},
            @{'Configuration' = 'IsoFiles'},
            @{'Configuration' = 'EasyCloud'}
        )
        
        $counter = 100 / $progressCounter

        $foldersToCreate | Foreach-Object {
            New-item "$mainPath/$_" -itemtype directory | Out-Null

            Foreach($subFolders in $subFoldersToCreate) {
                If($null -ne $subFolders.$_) {
                    $subFolder = $subFolders.$_
                    $path = "$mainPath\$_\$subFolder"
                    $path = $path.replace(' ', '')
                    New-item "$path" -itemtype directory | Out-Null
                }
            }

            Start-Sleep -Milliseconds 500
            $percentageComplete = "Percent complete : "+[math]::Round($counter)+"%"
            Write-Host $percentageComplete -ForegroundColor Green
            $progressCounter -= 1

            If($progressCounter -eq 0) {
                $progressCounter = 1
            }

            $counter = 100 / $progressCounter
        }

        $AppModulePath = ";$mainPath\App\Modules"
        $AppModulePath = $AppModulePath.Replace(" ", "")
   
        $CurrentValue = [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")

        If(($CurrentValue -notlike "*$AppModulePath*")) {
            [Environment]::SetEnvironmentVariable("PSModulePath", $CurrentValue + "$AppModulePath", "Machine")
            Write-Host "`nModule path added to environment variable" -ForegroundColor Green
        } else {
            Write-Host "`nEnvironment variable already exists" -ForegroundColor Yellow
        }

        Try {
            $IsoFolder = "$mainPath\Configuration\IsoFiles"
            $IsoFolder = $IsoFolder.replace(' ', '')

            New-SmbShare -Name "Iso" -Path $IsoFolder
            Write-Host "ISO File folder: IsoFolder" -ForegroundColor Green
        } Catch {
            Write-Error "Shared folder: $IsoFolder configuration failed"
            Uninstall-EasyCloud -Folder $mainPath
            Break;
        }
    }
}

Function Get-AppModules {
    Param (
        [Parameter(Mandatory=$true)]
        $installDir
    )
    Begin {
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        Write-Host "`nScript installation will start ..." -ForegroundColor Cyan
        #Getting ps1 script from git repo
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "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")
        $headers.Add("Accept", "application/vnd.github.VERSION.raw")

        Try {
            $Deployment = Invoke-RestMethod "https://raw.githubusercontent.com/Goldenlagen/EasyCloud_PSModules/main/VMDeployment/VMDeployment.psm1"
            Write-Host "Percent complete : 33%" -ForegroundColor Green
            Start-Sleep -Milliseconds 500
            $Configuration = Invoke-RestMethod "https://raw.githubusercontent.com/Goldenlagen/EasyCloud_PSModules/main/VMConfiguration/VMConfiguration.psm1"
            Write-Host "Percent complete : 66%" -ForegroundColor Green
            Start-Sleep -Milliseconds 500
            $Monitoring = Invoke-RestMethod "https://raw.githubusercontent.com/Goldenlagen/EasyCloud_PSModules/main/VMMonitoring/VMMonitoring.psm1"
            Write-Host "Percent complete : 100%" -ForegroundColor Green
        }

        Catch {
            Write-Host "Error while collecting modules files" -ForegroundColor Yellow
            Uninstall-EasyCloud -Folder $installDir
            Read-Host "Press Enter to exit"
            Break;
        }
    }

    Process {
        $scriptDir = "$installDir\App\Modules"
        $scriptDir = $scriptDir.replace(" ", "")

        If(Test-Path $scriptDir) {
            $Deployment | Out-File "$scriptDir\VMDeployment\VMDeployment.psm1" -Encoding utf8
            $Configuration | Out-File "$scriptDir\VMConfiguration\VMConfiguration.psm1" -Encoding utf8
            $Monitoring | Out-File "$scriptDir\VMMonitoring\VMMonitoring.psm1" -Encoding utf8
        } Else {
            Write-Error "Script folder cannot be find"
            Uninstall-EasyCloud -Folder $installDir
            Read-Host "Press enter to exit"
            Break;
        }
    } 
}

Function Get-GitApp {
    Param (
        [Parameter(Mandatory=$true)]
        $installDir,
        [Parameter(Mandatory=$true)]
        $dirURL,
        [Parameter(Mandatory=$true)]
        $Name
    )
    Begin {
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    }

    Process {
        $scriptDir = "$installDir\App\$Name"
        $scriptDir = $scriptDir.replace(" ", "")

        If(Test-Path $scriptDir) {
            Try { 
                $Zip = "$scriptDir\Zip.zip"

                Invoke-RestMethod -Uri $dirURL -OutFile $Zip
                Expand-Archive -Path $Zip -DestinationPath $scriptDir
                Remove-Item $Zip

                $Path = (Get-ChildItem -Path $scriptDir).Name

                $TempFile = "$scriptDir\$Path"

                Move-Item -Path (Get-ChildItem -Path ($TempFile)).FullName -Destination $scriptDir

                If ((Get-ChildItem $TempFile) -eq $null) {
                    remove-item "$TempFile"
                }

                Try {
                    Write-Host "Installating dependencies..." -ForegroundColor Cyan
                    Set-Location $scriptDir
                    npm i --silent
                }

                Catch {
                    Write-Error "Node library installation failed"
                    Uninstall-EasyCloud -Folder $installDir
                    Break;
                }

                Write-Host "$Name have been installed" -ForegroundColor Green
                Return $scriptDir
            }

            Catch {
                Write-Error "Error while collecting $Name files"
                Uninstall-EasyCloud -Folder $installDir
                Read-Host "Press enter to exit"
                Break;    
            }
        } Else {
            Write-Error "$Name folder cannot be find"
            Uninstall-EasyCloud -Folder $installDir
            Read-Host "Press Enter to exit"
            Break;
        }
    }
}

Function Set-EasyCloudADStrategy {
    Param (
        [Parameter(Mandatory)]
        $installDir
    )

    Process {
        $configDir = "$installDir\Configuration\IsoFiles"
        $configDir = $configDir.replace(" ", "")

        $DomainName = (Get-ADDomain).DistinguishedName

        Write-Host "`nCreation of the EasyCloud AD Strategy..." -ForegroundColor Cyan
        Start-Sleep -Seconds 2

        Try {
            New-ADOrganizationalUnit -Name "VIRTUALIZATION_SERVER" -Path $DomainName
        } Catch {
            Write-Host "OU=VIRTUALIZATION_SERVER already exist" -ForegroundColor Yellow
        }

        $EasyCloudOU = (Get-ADOrganizationalUnit -Identity "OU=VIRTUALIZATION_SERVER,$DomainName").DistinguishedName

        $groupToAdd = @(
            @{
                GroupName = "PROD_VIRTUALIZATION" 
                Description = "Virtualization servers for Production"
             },
            @{
                GroupName = "PREPROD_VIRTUALIZATION"
                Description ="Virtualization servers for Preproduction"
             },
    
            @{
                GroupName = "OTHER_VIRTUALIZATION"
                Description = "Other servers for virtualization"
            }
        )

        Foreach($group in $groupToAdd) {
            Try {
                New-ADGroup -Name $group.GroupName -Description $group.Description -Path $EasyCloudOU -GroupScope Global -GroupCategory Security -ErrorAction SilentlyContinue
                $groupname = $group.GroupName
                Write-Host "Group $groupname have been created" -ForegroundColor Green
            } Catch {
                $groupname = $group.GroupName
                Write-Host "Group $groupname already exists" -ForegroundColor Yellow
            }
        }
    }
}

Function Add-VirtualizationServer {
    Process {
        Write-Host "Please provide server name" -ForegroundColor Cyan
        $serverList = (Get-ADComputer -Filter *).Name
        $virtualizationServers = @()

        $serverList | ForEach-Object {
            $res = (Invoke-Command -ComputerName $_ -ScriptBlock {(Get-WindowsFeature -Name Hyper-V | Where-Object InstallState -eq "Installed")}).PSComputerName
            if($res -ne $null) {
                $virtualizationServers += $res
            }
        }

        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'Data Entry Form'
        $form.minimumSize = New-Object System.Drawing.Size(310,280)
        $form.maximumSize = New-Object System.Drawing.Size(310,280)
        $form.StartPosition = 'CenterScreen'

        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Location = New-Object System.Drawing.Point(75,170)
        $okButton.Size = New-Object System.Drawing.Size(75,23)
        $okButton.Text = 'OK'
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.AcceptButton = $okButton
        $form.Controls.Add($okButton)

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Location = New-Object System.Drawing.Point(150,170)
        $cancelButton.Size = New-Object System.Drawing.Size(75,23)
        $cancelButton.Text = 'Cancel'
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.CancelButton = $cancelButton
        $form.Controls.Add($cancelButton)

        $viewButton = New-Object System.Windows.Forms.Button
        $viewButton.Location = New-Object System.Drawing.Point(115,200)
        $viewButton.Size = New-Object System.Drawing.Size(75,23)
        $viewButton.Text = 'View Servers'
        $form.Controls.Add($viewButton)

        $viewButton.Add_Click({
            Write-Host "`n== Available Servers ==" -ForegroundColor Cyan
            $virtualizationServers | Foreach-Object {
                Write-Host "- $_" -ForegroundColor Cyan
            }
        })

        $prodlabel = New-Object System.Windows.Forms.Label
        $prodlabel.Location = New-Object System.Drawing.Point(10,20)
        $prodlabel.Size = New-Object System.Drawing.Size(280,20)
        $prodlabel.Text = 'PROD Server name to be added (SRV1,SRV02,...)'
        $form.Controls.Add($prodlabel)

        $prodBox = New-Object System.Windows.Forms.TextBox
        $prodBox.Location = New-Object System.Drawing.Point(10,40)
        $prodBox.Size = New-Object System.Drawing.Size(260,20)
        $form.Controls.Add($prodBox)

        $pprodlabel = New-Object System.Windows.Forms.Label
        $pprodlabel.Location = New-Object System.Drawing.Point(10,70)
        $pprodlabel.Size = New-Object System.Drawing.Size(500,20)
        $pprodlabel.Text = 'PREPROD Server name to be added (SRV1,SRV02,...)'
        $form.Controls.Add($pprodlabel)

        $pprodBox = New-Object System.Windows.Forms.TextBox
        $pprodBox.Location = New-Object System.Drawing.Point(10,90)
        $pprodBox.Size = New-Object System.Drawing.Size(260,20)
        $form.Controls.Add($pprodBox)

        $otherlabel = New-Object System.Windows.Forms.Label
        $otherlabel.Location = New-Object System.Drawing.Point(10,120)
        $otherlabel.Size = New-Object System.Drawing.Size(280,20)
        $otherlabel.Text = 'OTHER Server name to be added (SRV1,SRV02,...)'
        $form.Controls.Add($otherlabel)

        $otherBox = New-Object System.Windows.Forms.TextBox
        $otherBox.Location = New-Object System.Drawing.Point(10,140)
        $otherBox.Size = New-Object System.Drawing.Size(260,20)
        $form.Controls.Add($otherBox)

        $form.Topmost = $true

        $form.Add_Shown({$prodBox.Select()})
        $form.Add_Shown({$pprodBox.Select()})
        $form.Add_Shown({$otherBox.Select()})
        $result = $form.ShowDialog()

        If($result -eq [System.Windows.Forms.DialogResult]::OK -and $prodBox.Text -eq "" -and $pprodBox.Text -eq "" -and $otherBox.Text -eq "") {
            Add-VirtualizationServer
        } 

        ElseIf ($result -eq [System.Windows.Forms.DialogResult]::OK)
        {
            $PRODServer = $prodBox.Text
            $PPRODServer = $pprodBox.Text
            $OTHERServer = $otherBox.Text

            Write-Host " "

            If($PRODServer) {
                Write-Host "Selected Servers for PROD : $PRODServer" -ForegroundColor Cyan  
            }

            If($PPRODServer) {
                Write-Host "Selected Servers for PPROD : $PPRODServer" -ForegroundColor Cyan  
            }

            If($OTHERServer) {
                Write-Host "Selected Servers for Other : $OTHERServer" -ForegroundColor Cyan  
            }

            Write-Host " "

            $serverToAdd = @{
                PROD = $PRODServer
                PPROD = $PPRODServer
                OTHER = $OTHERServer
            }

            $serverToAdd.Keys | Foreach-Object {
                Try {
                    $filterServer = $serverToAdd.$_ -split(',')

                    Foreach($server in $filterServer) {
                        Get-ADComputer -Identity $server | Out-Null

                        Switch($_) {
                            "PROD" {
                                Write-Host "Server $filterServer added in Production environment" -ForegroundColor Green
                                $Group = "PROD_VIRTUALIZATION"
                            }

                            "PPROD" {
                                Write-Host "Server $filterServer added in Preproduction environment" -ForegroundColor Green
                                $Group = "PREPROD_VIRTUALIZATION"
                            }
                            "OTHER" {
                                Write-Host "Server $filterServer added in Other environment" -ForegroundColor Green
                                $Group = "OTHER_VIRTUALIZATION"
                            }
                        }

                        Add-ADGroupMember -Identity $Group -Members (Get-ADComputer -Identity $server)

                        If(Invoke-Command -ScriptBlock {Test-Path "C:\EasyCloud\VirtualMachines\Disk"} -ComputerName $server) {
                    
                        } Else {
                            Invoke-Command -ScriptBlock {New-Item -Path "C:\EasyCloud\VirtualMachines\Disk" -ItemType Directory} -ComputerName $server
                        }

                        If(Invoke-Command -ScriptBlock {Test-Path "C:\EasyCloud\VirtualMachines\VM"} -ComputerName $server) {
                    
                        } Else {
                            Invoke-Command -ScriptBlock {New-Item -Path "C:\EasyCloud\VirtualMachines\VM" -ItemType Directory} -ComputerName $server
                        }                          
                    }
                }

                Catch {
                    If($filterServer) {
                        Write-Host "Server: $filterServer not found" -ForegroundColor Yellow
                        Add-VirtualizationServer
                    }
                }
            }

            Write-Host "`nInstallation Complete" -ForegroundColor Green
        }
    }
}

Function Register-AppShortcut {
    Param (
        [Parameter(Mandatory)]
        $ShPath,
        [Parameter(Mandatory)]
        $ShTargetPath,
        [Parameter()]
        $ShArguments,
        [Parameter()]
        $IconPath,
        [Parameter()]
        $ShWorkingDirPath = ""
    )

    Process {
        Write-Host "`nCreating launch icon..." -ForegroundColor Cyan 
        $ShPath = $ShPath.replace(" ", "")
        $ShWorkingDirPath = $ShWorkingDirPath.replace(" ", "")
        
        $Shell = New-Object -ComObject ("WScript.Shell")
        $Shortcut = $Shell.CreateShortcut($ShPath)

        $Shortcut.TargetPath = $ShTargetPath

        If($IconPath) {
            $Shortcut.IconLocation = $IconPath.replace(" ", "")
        }

        If($ShWorkingDirPath) {
            $Shortcut.WorkingDirectory = $ShWorkingDirPath
        }

        If($ShArguments) {
            $Shortcut.Arguments = $ShArguments
        }

        $Shortcut.Save()
        Write-Host "Successfully created" -ForegroundColor Green
    }
}

Function Pop-ApplicationLauncher {
    Param (
        [Parameter(Mandatory)]
        $BackServerLocation,
        [Parameter(Mandatory)]
        $FrontAppLocation
    )

    Process {
        $form = New-Object System.Windows.Forms.Form
        $form.Text = 'EasyCloud Launcher'
        $form.Size = New-Object System.Drawing.Size(300,200)
        $form.maximumSize = New-Object System.Drawing.Size(300,200)
        $form.minimumSize = New-Object System.Drawing.Size(300,200)
        $form.StartPosition = 'CenterScreen'
        $form.BackColor = "White"

        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Location = New-Object System.Drawing.Point(50,120)
        $okButton.Size = New-Object System.Drawing.Size(100,23)
        $okButton.Text = 'Launch'
        $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.AcceptButton = $okButton
        $form.Controls.Add($okButton)

        $image1 = New-Object System.Windows.Forms.pictureBox
        $image1.Location = New-Object Drawing.Point 40,40
        $image1.Size = New-Object System.Drawing.Size(100,100)
        Try {
            $image1.image = [system.drawing.image]::FromFile("./EasyCloudLogo.png")
        } Catch {}
        $form.controls.add($image1)

        $cancelButton = New-Object System.Windows.Forms.Button
        $cancelButton.Location = New-Object System.Drawing.Point(160,120)
        $cancelButton.Size = New-Object System.Drawing.Size(75,23)
        $cancelButton.Text = 'Exit'
        $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.CancelButton = $cancelButton
        $form.Controls.Add($cancelButton)

        $form.Topmost = $true
        $result = $form.ShowDialog()

        If ($result -eq [System.Windows.Forms.DialogResult]::OK)
        {
            Try {
                Start-Process "$installDir\Configuration\StartBackServer.lnk"
                Start-Process "$installDir\Configuration\LaunchWebInterface.lnk"
            }

            Catch {
                Write-Error "Failed to launch $installDir\Configuration\StartBackServer.lnk `n$installDir\Configuration\LaunchWebInterface.lnk"
            }
        }
    }
}

Function Start-Installation {
    Start-Sleep -Seconds 1
    If(!$isWindows) {       
        Write-Host "OS: Windows" -ForegroundColor Green
        $installDir = Get-InstallFolder
        Check-GitInstalled
        Check-NodeJSInstalled

        Start-Sleep -Seconds 10

        Add-FolderStructure $installDir
        Get-AppModules $installDir
        
        Write-Host "`nCollecting Application files..." -ForegroundColor Cyan
        
        $BackPath = Get-GitApp -installDir $installDir -Name "BackServer" -dirURL "https://github.com/Hugouverneur/easyCloudBackend/archive/refs/heads/main.zip"
        $FrontPath = Get-GitApp -installDir $installDir -Name "WebInterface" -dirURL "https://github.com/Hugouverneur/easyCloud/archive/refs/heads/main.zip"

        Start-Sleep -Seconds 2
        Set-EasyCloudADStrategy -installDir $installDir

        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        $url = "https://raw.githubusercontent.com/Goldenlagen/EasyCloud_PSModules/main/EasyCloudLogo.ico"

        $installLocation = "$installDir\Configuration\EasyCloud\EasyCloudLogo.ico"
        $installLocation = $installLocation.replace(" ", "")

        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($url, $installLocation)

        $url = "https://github.com/Goldenlagen/EasyCloud_PSModules/raw/main/InstallationPackage/EasyCloudUninstaller.exe"

        $installLocation = "$installDir\EasyCloudUninstall.exe"
        $installLocation = $installLocation.replace(" ", "")

        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($url, $installLocation)

        Register-AppShortcut -ShPath "C:\users\public\desktop\Portal EasyCloud.lnk" -ShTargetPath "http://localhost:4200" -IconPath "$installDir\Configuration\EasyCloud\EasyCloudLogo.ico"
        Register-AppShortcut -ShPath "$installDir\Portal EasyCloud.lnk" -ShTargetPath "http://localhost:4200" -IconPath "$installDir\Configuration\EasyCloud\EasyCloudLogo.ico"

        Register-AppShortcut -ShPath "$installDir\Configuration\StartBackServer.lnk" -ShTargetPath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ShArguments '-WindowStyle Hidden -Command node .' -ShWorkingDirPath "$BackPath"
        Register-AppShortcut -ShPath "$installDir\Configuration\LaunchWebInterface.lnk" -ShTargetPath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ShArguments '-WindowStyle Hidden -Command ng serve' -ShWorkingDirPath "$FrontPath"

        Write-Host "`nServer configuration will start" -ForegroundColor Green
        Add-VirtualizationServer
        Pop-ApplicationLauncher -FrontAppLocation "C:\New\App\WebInterface" -BackServerLocation "C:\New\App\BackServer"
        Read-Host "Press enter to exist"
    } Else {
        Write-Warning "System is not a Windows OS"
        Break;
    }
}

Function Uninstall-EasyCloud {
    Param(
        [Parameter(Mandatory)]
        $installFolder
    )

    Process {
        Remove-SmbShare -Name Isofiles

        $moduleFolder = ";$installFolder\App\Modules"
        $moduleFolder = $moduleFolder.replace(" ","")
        
        $str = $env:PSModulePath

        $str.Contains($moduleFolder)

        $str = $str.replace($moduleFolder, $null)

        [Environment]::SetEnvironmentVariable("PSModulePath", $str, "Machine")

        Remove-Item -Path $installFolder
    }
}

Start-Installation