Clear-Host;

Function Update-VMMemory {
    <#
        .SYNOPSIS
            Change memory allocated on a virtual machine
        .EXAMPLE
            Update-VMMemory -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -NewVMRam 2GB -VirtualizationServerName VMSRV01
        .INPUTS
            VirtuaMachine id
            VirtualMachine new allocated memory
            Virtualization server name
        .OUTPUTS
            Confirmation message
        .DESCRIPTION
            This function will update the memory allocated to the provided virtual machine with
            set vm memory command, the virtual machine have to be turned off before
        .NOTES
            Function called when settings form is commited
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmconfiguration
    #>
    Param(
        [Parameter(mandatory=$true)]
        [String]$VMId,
        [Parameter(mandatory=$true)]
        [String]$NewVMRam,
        [Parameter(mandatory=$true)]
        [String]$VirtualizationServerName
    )

    Begin {
        Write-Host "(i) Modification of the number of RAM allocated..." -ForegroundColor Cyan
    }

    Process {
        Try {
            $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServerName
            $VMName = $VM.Name
            Set-VMMemory -VMName $VMName -StartupBytes $NewVMRam -ComputerName $VirtualizationServerName
            Return "(/) Memory have been set to: $NewVMRam for $VMName"
        } 
        
        Catch {
            Return "(x) An error occured, memory haven't been changed"
        }
    }
}

Function Update-VMVCPU {
    <#
        .SYNOPSIS
            Change number of virtual cpu allocated on a virtual machine
        .EXAMPLE
            Update-VMVCPU -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -NewVMVCPU 2 -VirtualizationServerName VMSRV01
        .INPUTS
            VirtuaMachine id
            VirtualMachine new number of vcpu
            Virtualization server name
        .OUTPUTS
            Confirmation message
        .DESCRIPTION
            This function will update the number of vcpu allocated with set vm processor command
            the virtual machine have to be turned off before
        .NOTES
            Function called when settings form is commited
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmconfiguration
    #>
    Param(
        [Parameter(mandatory=$true)]
        [String]$VMId,
        [Parameter(mandatory=$true)]
        [Int]$NewVMVCPU,
        [Parameter(mandatory=$true)]
        [String]$VirtualizationServerName
    )

    Begin {
        Write-Host "(i) Readjustment of the number of VCPU..." -ForegroundColor Cyan
    }

    Process {
        Try {
            $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServerName
            $VMName = $VM.Name

            $Cores = (Get-WmiObject -Class WIn32_Processor).NumberOfLogicalProcessors

            If($NewVMVCPU -gt ($Cores / 2)) {
                Return "(x) Number of cores specified is too much, number of VCPU haven't been changed"
            }

            Set-VMProcessor -VMName $VMName -Count $NewVMVCPU -ComputerName $VirtualizationServerName
            Return "(/) Number of VCPU have been set to: $NewVMVCPU for $VMName"
        } 
        
        Catch {
            Return "(x) An error occured, number of VCPU haven't been changed"
        }
    }
}

Function Add-VMDisk {
    <#
        .SYNOPSIS
            Add a new disk for a virtual machine
        .EXAMPLE
            Add-VMDisk -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VMDiskName "Disk01" -VMDiskSize 30GB -VirtualizationServerName VMSRV01
        .INPUTS
            VirtuaMachine id
            New disk name
            New disk size
            Virtualization server name
        .OUTPUTS
            Confirmation message
        .DESCRIPTION
            This function will create and add a new disk to a virtual machine with new vhd command
            and Add vm hard disk drive command, the virtual machine have to be turned off before
        .NOTES
            Function called when settings form is commited
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmconfiguration
    #>
   Param(
        [Parameter(mandatory=$true)]
        [String]$VMId,
        [Parameter(mandatory=$true)]
        [String]$VMDiskName,
        [Parameter(mandatory=$true)]
        $DiskSize,
        [Parameter(mandatory=$true)]
        [String]$VirtualizationServerName
    )

    Begin {
        Write-Host "(i) Disk will be created ..." -ForegroundColor Cyan
        $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServerName
        $VMName = $VM.Name
        $DiskName = $VMDiskName+".vhdx"
    }

    Process {
        Try {
            $DiskPath = "C:\EasyCloud\VirtualMachines\Disk\$DiskName"
            Write-Host "New-VHD -Path $DiskPath -SizeBytes $DiskSize -ComputerName $VirtualizationServerName"
            New-VHD -Path $DiskPath -SizeBytes $DiskSize -ComputerName $VirtualizationServerName | Out-Null
            Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -Path $DiskPath -ComputerName $VirtualizationServerName

            If((Get-VMHardDiskDrive -ComputerName VMSRV01 -VMName MyVM01).Path -eq $DiskPath) {
                Return "(/) Disk have been created"
            } Else {
                Invoke-Command -ComputerName $VirtualizationServerName {
                    param($Path)
                    Remove-Item -Path $Path
                } -ArgumentList $DiskPath

                Return "(x) An error occured, disk size haven't been created"
            }
        }

        Catch {
            Return "(x) An error occured, disk size haven't been created"
        }
    }
}

Function Dismount-VMDisk {
    <#
        .SYNOPSIS
            Delete a disk for a virtual machine
        .EXAMPLE
            Dismount-VMDisk -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VMDiskName "Disk01" -VirtualizationServerName VMSRV01
        .INPUTS
            VirtuaMachine id
            Disk name
            Virtualization server name
        .OUTPUTS
            Confirmation message
        .DESCRIPTION
            This function will delete a disk from a provided virtual machine by using remove vm hard disk drive command
            the virtual machine have to be turned off before
        .NOTES
            Function called when settings form is commited
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmconfiguration
    #>
   Param(
        [Parameter(mandatory=$true)]
        [String]$VMId,
        [Parameter(mandatory=$true)]
        [String]$VMDiskName,
        [Parameter(mandatory=$true)]
        [String]$VirtualizationServerName
    )

    Begin {
        Write-Host "(i) Disk will be removed from the VM ..." -ForegroundColor Cyan
        $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServerName
        $VMName = $VM.Name
    }

    Process {
        Try {
            $VMDiskPath = "C:\EasyCloud\VirtualMachines\Disk\$VMDiskName"+".vhdx"
            $ControllerValue = Get-VMHardDiskDrive -VMName $VMName -ComputerName $VirtualizationServerName | Where-Object Path -eq "$VMDiskPath"
            $ControllerValue | Remove-VMHardDiskDrive

            If($null -eq (Get-VMHardDiskDrive -ComputerName VMSRV01 -VMName MyVM01 | Where-Object Path -eq $VMDiskPath).Path) {
                Invoke-Command -ComputerName $VirtualizationServerName {
                    param($Path)
                    Remove-Item -Path $Path
                } -ArgumentList $VMDiskPath

                Return "(/) Disk $VMDiskName have been removed from the VM $VMName" 
            }

            Else {
                Return "(x) An error occured, the disk haven't been removed from the VM"
            }
        }

        Catch {
            Return "(x) An error occured, the disk haven't been removed from the VM"
        }
    }
}

Export-ModuleMember -Function Dismount-VMDisk, Add-VMDisk, Update-VMVCPU, Update-VMMemory
