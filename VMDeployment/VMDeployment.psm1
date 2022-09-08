$MainFolder = (Get-Item -Path $PSScriptRoot).Parent.FullName
$ConfigurationPath = ($MainFolder | Split-Path | Split-Path) + "\Configuration"
$ApplicationPath = ($MainFolder | Split-Path | Split-Path) + "\App"
Import-Module VMMonitoring


Function Start-Application {
    Process {
        $EasyCloudConfig = $ConfigurationPath + "\EasyCloud"

        $AppToStart = @(
            @{
                Path = "$ApplicationPath\WebInterface"
                Command = "ng"
                Args = "serve"
                Description = "AngularWebApp"
                OutPath = "FRONT_DATA.psd1"
            },
            @{
                Path = "$ApplicationPath\BackServer"
                Command = "node"
                Args = "."
                Description = "NodeJsServer"
                OutPath = "BACK_DATA.psd1"
            }
        )

        $AppToStart | ForEach-Object {
            $webapp = New-Object System.Diagnostics.ProcessStartInfo
            $webapp.FileName = $_.Command
            $webapp.Arguments = $_.Args
            $webapp.WorkingDirectory = $_.Path
            $webapp.WindowStyle = 'Hidden'
            $webapp.CreateNoWindow = $True

            $Process = [Diagnostics.Process]::Start($webapp)

            $ProcessName = $Process.ProcessName
            $ProcessId = $Process.Id
            $Description = $_.Description
            $OutPath = $EasyCloudConfig + "\" + $_.OutPath

            "@{
                ProcessType = '$ProcessName'
                ProcessName = '$Description'
                ProcessId = $ProcessId
            }" | Out-File $OutPath  
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

Function Add-VMConnectionShortcut {
    Param(
        [Parameter(Mandatory)]
        [String]$VirtualizationServerName,

        [Parameter(Mandatory)]
        [String]$VMId
    )

    Process {
        $Path = $MainFolder | Split-Path
        $Path = "$Path\WebInterface\src\assets\vmconnect-files\$VMId"
        $Path += ".lnk"

        $Command = "vmconnect $VirtualizationServerName -G $VMId"

        Register-AppShortcut -ShPath $Path -ShTargetPath 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -ShArguments "-WindowStyle Hidden -Command $Command"
    }
}

Function Get-VMDeploymentPath {
    $Path = (Get-Module VMDeployment).Path

    $PathArray = $Path.split('\')

    $basePath = ""

    $PathArray | ForEach-Object {
        If($_ -match 'EasyCloud') {
            For ($i=0; $i -lt $PathArray.IndexOf($_) + 1; $i++) {
                $basePath += $PathArray[$i]+"\"
            }
        }
    } 

    Set-Location $basePath
    Return $basePath
}

Function Find-DiskExistence {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$VMDisk,
        [Parameter(Mandatory=$true)]
        [String]$VirtualizationServerName
    )

    Process {
        $DiskList = Invoke-Command -ScriptBlock {ls -Path "C:\EasyCloud\VirtualMachines\Disk\" | Select-Object Name | Where-Object Name -like "$VMDisk"} -ComputerName $VirtualizationServerName

        If($null -eq $DiskList) {
            Write-Host "Deployment of a new virtual machine started..." -ForegroundColor Cyan
            Return $VMDisk
        }

        Else {
            Return "NA"
        }
    }
}

Function Get-AvailableIso {
    <#
        .SYNOPSIS
            Retrieve a liste of available ISO
        .EXAMPLE
            Get-AvailableIso
        .INPUTS
            None
        .OUTPUTS
            List of ISO file as string formated into JSON
        .DESCRIPTION
            This script will read a shared folder where are stored iso file for the application
            and will return a list as JSON
        .NOTES
            Function called on virtual machine creation page
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmdeployment
    #>
    $shareServer = (hostname).ToUpper()
    $IsoList = New-Object System.Collections.ArrayList

    $i = 0

    ((ls -Path "\\$shareServer\Iso").Name) | ForEach-Object {
        If($_ -match ('.iso')) {
            $IsoList.Add(@{
                "Folder" = $shareServer 
                "Filename" = "$_" 
            }) | Out-Null
        }
    }

    $IsoList = ConvertTo-Json -InputObject $IsoList

    Return $IsoList      
}

Function Add-NewVM {
    <#
        .SYNOPSIS
            Create a new virtual machine
        .EXAMPLE
            Add-NewVM -VMName MyVM01 -VMRAM 2GB -VMDiskSize 50GB -VMOS "\\EASYCLOUD-APP\Iso\Windows2019.iso" -VMProcessor 2 -VirtualizationServer VMSRV01
        .INPUTS
            VirtuaMachine name
            VirtualMachine allocated memory
            VirtualMachine default disk size
            VirtualMachine OS selected
            VirtualMachine virtual processor number
            VirutalMachine virtualization server 
        .OUTPUTS
            Confirmation message and virtual machine Id
        .DESCRIPTION
            This function will create a new virtual machine step by step by checking many parameters, if disk already exist or if allocated
            resource are not execeding virtualization server resource. It use new-vm command. 
        .NOTES
            Function called on virtual machine creation form commited
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmdeployment
    #>
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [String]$VMName,
        [Parameter(Mandatory=$true)]
        $VMRam,
        [Parameter(Mandatory=$true)]
        $VMDiskSize,
        [Parameter(Mandatory=$true)]
        [String]$VMOS,
        [Parameter(Mandatory=$true)]
        [Int]$VMProcessor,
        [Parameter(Mandatory=$true)]
        [String]$VirtualizationServer
    )

    Begin {
        $Path = Get-VMDeploymentPath
    }

    Process {
        Try {
            $VMDisk = "$VMName" + ".vhdx"
            $VMDiskPath = "C:\EasyCloud\VirtualMachines\Disk\$VMDisk"
            $DiskChecker = Find-DiskExistence -VMDisk $VMDisk -VirtualizationServerName $VirtualizationServer
            $VMPath = "C:\EasyCloud\VirtualMachines\VM\$VMName"
            $VMGeneration = 1
            $VMSwitchName = "InternalSwitch"
            $MachineCores = (Get-WmiObject Win32_processor -ComputerName $VirtualizationServer | Select-Object NumberOfLogicalProcessors)

            If($DiskChecker -eq "NA") {
                Write-Error "Disk with same name already exist"
                Write-Host "(x) Deployment failed" -ForegroundColor Red
                Break;
            }

            If($VMProcessor -gt $MachineCores.NumberOfLogicalProcessors) {
                Write-Error "Number of virtual cores attributed are outpassing physical server number"
                Write-Host "(x) Deployment failed" -ForegroundColor Red
                Break;
            }

            If(Get-VMSwitch -ComputerName $VirtualizationServer | Where-Object Name -like InternalSwitch) {
                Write-Host "InternalSwitch exist" -ForegroundColor Green
            } Else {
                New-VMSwitch -name 'InternalSwitch' -NetAdapterName Ethernet -AllowManagementOS $true -ComputerName $VirtualizationServer
            }

            $Command = "New-VM -Name $VMName -ComputerName $VirtualizationServer -MemoryStartupBytes $VMRam -NewVHDPath '$VMDiskPath' -NewVHDSizeBytes $VMDiskSize -Path "+ "'$VMPath' " + "-Generation $VMGeneration -SwitchName '$VMSwitchName'"

            Invoke-Expression $Command

            Try {
                Write-Host "Add-VMDvdDrive -VMName $VMName -Path "$VMOS" -ComputerName $VirtualizationServer"
                Add-VMDvdDrive -VMName $VMName -Path "$VMOS" -ComputerName $VirtualizationServer
                Set-VMProcessor $VMName -Count $VMProcessor -ComputerName $VirtualizationServer
                Write-Host "(/) Sucessful verification" -ForegroundColor Green
            } 
            
            Catch {
                Write-Warning "(x) Verification failed"
                Break;
            }

            Write-Host "(/) Sucessful deployment" -ForegroundColor Green
            
            $VMId = (Get-VM -Name $VMName -ComputerName $VirtualizationServer).Id

            Try {
                Write-Host "Start config"
                $ConfigPath = "$MainFolder\VMMonitoring\Configuration.json"

                $Conf = Get-Content $ConfigPath | ConvertFrom-Json
                $VMId = (Get-VM -Name $VMName -ComputerName $VirtualizationServer).Id 

                Update-MonitoringMode -VMId  $VMId -isMonitored $False -ServerName $VirtualizationServer
            }

            Catch {
                Write-Host "Failed to register configuration data"
            }
        } 
        
        Catch {
            Write-Warning "An error occured in the execution"
            Write-Host "(x) Deployment failed" -ForegroundColor Red
        }

        Add-VMConnectionShortcut -VirtualizationServerName $VirtualizationServer  -VMId $VMId

        Return "Id: $VMId"
    }
}

Function Uninstall-VM {
    <#
        .SYNOPSIS
            Uninstall a virtual machine
        .EXAMPLE
            Uninstall-VM -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VirtualizationServer VMSRV01
        .INPUTS
            VirtuaMachine id
            Virtualization server name
        .OUTPUTS
            Confirmation message
        .DESCRIPTION
            This function will delete the virtual machine data that is provided, virtual machine files
            and disk file
        .NOTES
            Function called on virtual machine creation form commited
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmdeployment
    #>
    Param(
        [Parameter(Mandatory=$true)]
        [String]$VMId,
        [Parameter(Mandatory=$true)]
        [String]$VirtulizationServer
    )

    Process {
        Try {
            $VMToDelete = (Get-VM -Id $VMId -ComputerName $VirtulizationServer)

            $VMName = $VMToDelete.Name

            $VMDisk = "C:\EasyCloud\VirtualMachines\Disk\" + "$VMName"+".vhdx"

            Invoke-Command -ScriptBlock {Remove-Item -Path $Using:VMDisk} -ComputerName $VirtulizationServer

            $VMToDelete | Remove-VM -Force

            $Config = Get-Content -Path "$MainFolder\VMMonitoring\Configuration.json" | ConvertFrom-Json

            $Config.PsObject.Members.Remove($VMId) | ConvertTo-Json | Out-File $Config

            If((Get-VM -Id $VMId -ComputerName $VirtulizationServer)) {
                Write-Error "VM $VMName have not been deleted"
            } Else {
                Write-Host "Virtual machine have been deleted" -ForegroundColor Green
            }
        } Catch {
            Write-Error "A problem occured during the deletion"
        }
    }
}

Export-ModuleMember -Function Add-NewVM, Uninstall-VM, Get-AvailableIso, Start-Application, Add-VMConnectionShortcut
