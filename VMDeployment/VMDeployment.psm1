
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
        $Path += ".bat"

        $Command = "vmconnect $VirtualizationServerName -G $VMId"

        New-Item -Path $Path -Value $Command | Out-Null
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
        $DiskList = Invoke-Command -ScriptBlock {ls -Path "C:\EasyCloud\VirtualMachines\Disk\" | Select-Object Name | Where-Object Name -match "$VMDisk"} -ComputerName $VirtualizationServerName

        If($DiskList.Lenght -ne 0) {
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
            $Output = New-Object System.Collections.ArrayList
            $LogOutput = New-Object System.Collections.ArrayList

            $VMDisk = "$VMName" + ".vhdx"
            $VMDiskPath = "C:\EasyCloud\VirtualMachines\Disk\$VMDisk"
            $DiskChecker = Find-DiskExistence -VMDisk $VMDisk -VirtualizationServerName $VirtualizationServer
            $VMPath = "C:\EasyCloud\VirtualMachines\VM\$VMName"
            $VMGeneration = 1
            $VMSwitchName = "InternalSwitch"
            $MachineCores = (Get-WmiObject Win32_processor -ComputerName $VirtualizationServer | Select-Object NumberOfLogicalProcessors)

            If($DiskChecker -eq "NA") {
                $LogOutput.Add(@{
                    Step = 1
                    Message = "Disk with same name already exist"
                    Status = "NOK"
                }) | Out-Null

                Return $LogOutput | ConvertTo-Json
            }

            Else {
                $LogOutput.Add(@{
                    Step = 1
                    Message = "Disk path is correct"
                    Status = "OK"
                }) | Out-Null
            }

            If($VMProcessor -gt $MachineCores.NumberOfLogicalProcessors) {
                $LogOutput.Add(@{
                    Step = 2
                    Message = "Number of virtual cores attributed are outpassing physical server number"
                    Status = "NOK"
                }) | Out-Null
                
                Return $LogOutput | ConvertTo-Json
            }

            Else {
                $LogOutput.Add(@{
                    Step = 2
                    Message = "Number of virtual cores have been attributed"
                    Status = "OK"
                }) | Out-Null
            }

            If(Get-VMSwitch -ComputerName $VirtualizationServer | Where-Object Name -like InternalSwitch) {
                $LogOutput.Add(@{
                    Step = 3
                    Message = "Switch already exist, it will be used"
                    Status = "OK"
                }) | Out-Null
            } Else {
                New-VMSwitch -name 'InternalSwitch' -NetAdapterName Ethernet -AllowManagementOS $true -ComputerName $VirtualizationServer
            }

            $Command = "New-VM -Name $VMName -ComputerName $VirtualizationServer -MemoryStartupBytes $VMRam -NewVHDPath '$VMDiskPath' -NewVHDSizeBytes $VMDiskSize -Path "+ "'$VMPath' " + "-Generation $VMGeneration -SwitchName '$VMSwitchName'"

            Invoke-Expression $Command | Out-Null

            Try {
                Add-VMDvdDrive -VMName $VMName -Path "$VMOS" -ComputerName $VirtualizationServer
                Set-VMProcessor $VMName -Count $VMProcessor -ComputerName $VirtualizationServer
                
                $LogOutput.Add(@{
                    Step = 4
                    Message = "Successfull Verification"
                    Status = "OK"
                }) | Out-Null
            } 
            
            Catch {
                $LogOutput.Add(@{
                    Step = 4
                    Message = "Verification Failed"
                    Status = "NOK"
                }) | Out-Null

                Return $LogOutput | ConvertTo-Json
            }

            $LogOutput.Add(@{
                Step = 5
                Message = "Sucessful VM creation"
                Status = "OK"
            }) | Out-Null
            
            $VMId = (Get-VM -Name $VMName -ComputerName $VirtualizationServer).Id

            # Try {
            #     Write-Host "Start config"
            #     $ConfigPath = "$MainFolder\VMMonitoring\Configuration.json"

            #     $Conf = Get-Content $ConfigPath | ConvertFrom-Json
            #     $VMId = (Get-VM -Name $VMName -ComputerName $VirtualizationServer).Id 

            #     Update-MonitoringMode -VMId  $VMId -isMonitored $False -ServerName $VirtualizationServer
            # }

            # Catch {
            #     Write-Host "Failed to register configuration data"
            # }
        } 
        
        Catch {
            $LogOutput.Add(@{
                Message = "An error occured during execution"
                Status = "NOK"
            }) | Out-Null

            Return $LogOutput | ConvertTo-Json
        }

        Add-VMConnectionShortcut -VirtualizationServerName $VirtualizationServer  -VMId $VMId

        $Output.Add(@{
            Log = $LogOutput
            VMId = $VMId
        }) | Out-Null

        Return $Output | ConvertTo-Json
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
        [Parameter(Mandatory)]
        [String]$VMId,

        [Parameter(Mandatory)]
        [String]$VirtualizationServerName
    )

    Process {
        Try {
            $LogOutput = New-Object System.Collections.ArrayList
            $VMToDelete = (Get-VM -Id $VMId -ComputerName $VirtualizationServerName)
            $VMName = $VMToDelete.Name
            $VMDisk = "C:\EasyCloud\VirtualMachines\Disk\" + "$VMName"+".vhdx"

            Try {
                Invoke-Command -ScriptBlock {Remove-Item -Path $Using:VMDisk} -ComputerName $VirtualizationServerName
                
                $LogOutput.Add(@{
                    Step = 1
                    Message = "VM Disk have been deleted"
                    Status = 'OK'
                }) | Out-Null
            }

            Catch {
                $LogOutput.Add(@{
                    Step = 1
                    Message = "An error occured during VM Disk deletion"
                    Status = 'NOK'
                }) | Out-Null

                Return $LogOutput | ConvertTo-Json
            }

            Try {
                $VMToDelete | Remove-VM -Force -ErrorAction Stop

                $LogOutput.Add(@{
                    Step = 2
                    Message = "VM have been deleted"
                    Status = 'Ok'
                }) | Out-Null

            }

            Catch {
                $LogOutput.Add(@{
                    Step = 2
                    Message = "Error occured during VM deletion"
                    Status = 'NOK'
                }) | Out-Null

                Return $LogOutput | ConvertTo-Json
            }

            Return $LogOutput | ConvertTo-Json
        } 
        
        Catch {
            $LogOutput.Add(@{
                Message = "An error occured during execution"
                Status = 'NOK'
            }) | Out-Null

            Return $LogOutput | ConvertTo-Json
        }
    }
}

Export-ModuleMember -Function Add-NewVM, Uninstall-VM, Get-AvailableIso, Start-Application
