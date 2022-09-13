
$MainFolder = (Get-Item -Path $PSScriptRoot).Parent.FullName
$ConfigurationPath = ($MainFolder | Split-Path | Split-Path) + "\Configuration"
$ApplicationPath = ($MainFolder | Split-Path | Split-Path) + "\App"
Import-Module VMMonitoring

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
            Retrieve the list of available ISO located in "C:\EasyCloud\Configuration\IsoFiles" folders
        
        .DESCRIPTION
            Retrieve the list of available ISO located in "C:\EasyCloud\Configuration\IsoFiles" folders

        .INPUTS
            None
        
        .OUTPUTS
            List of ISO file as string formated into JSON
        
        .EXAMPLE
            PS> Get-AvailableIso

        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMDeployment
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
        
        .DESCRIPTION
            Create a new virtual machine
            Take a virtual machine name, allocated RAM, number of v-core attributed, the default disk max size, an iso file path and a virtualization server name
        
        .INPUTS
            VirtualMachine name as pipeline value

        .OUTPUTS
            Return VM Id and creation steps log else return error logs

        .EXAMPLE
            PS> Add-NewVM -VMName MyVM01 -VMRAM 2GB -VMDiskSize 50GB -VMOS "\\EASYCLOUD-APP\Iso\Windows2019.iso" -VMProcessor 2 -VirtualizationServer VMSRV01

        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMDeployment
    #>
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        #Provide a virtual machine name
        [String]$VMName,

        [Parameter(Mandatory)]
        #Provide number of allocated RAM 
        [UInt64]$VMRam,

        [Parameter(Mandatory)]
        #Provide size of the virtual machine disk
        [UInt64]$VMDiskSize,

        [Parameter(Mandatory)]
        #Provide the path to an exploitation system iso file
        [String]$VMOS,

        [Parameter(Mandatory)]
        #Provide number of attributed v-core
        [Int]$VMProcessor,

        [Parameter(Mandatory)]
        #Provide the virtualization server name where the virtual machine will be created
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
            Uninstall and delete all file related to a virtual machine

        .DESCRIPTION
            Uninstall and delete all file related to a virtual machine
            Take a virtual machine Id and a virtualization server name

        .INPUTS
            None

        .OUTPUTS
            Log with OK status else return log error
        
        .EXAMPLE
            PS> Uninstall-VM -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VirtualizationServer VMSRV01
        
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMDeployment
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

Export-ModuleMember -Function Add-NewVM, Uninstall-VM, Get-AvailableIso
