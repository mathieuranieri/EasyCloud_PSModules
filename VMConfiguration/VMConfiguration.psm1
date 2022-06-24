Clear-Host;

$Global:DiskPath = "F:\ESTIAM\M1 - ESTIAM\PIM\EasyCloud\VM_HardDrive"

Function Update-VMMemory {
    <#
        .SYNOPSIS
            Change memory allocated on a virtual machine
        .EXAMPLE
            Update-VMMemory -VMId <String> -NewVMRam <Int32>
        .INPUTS
            VirtuaMachine id
            VirtualMachine new allocated memory
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
        [String]$NewVMRam
    )

    Begin {
        Write-Host "(i) Modification of the number of RAM allocated..." -ForegroundColor Cyan
    }

    Process {
        Try {
            $Command = "Get-VM -Id $VMId | Set-VMMemory -StartupBytes $NewVMRam -PassThru | Out-Null"
            Invoke-Expression $Command
            Write-Host " "
            Write-Host "(/) Memory have been set to: $NewVMRam" -ForegroundColor Green
            Write-Host " "
        } 
        
        Catch {
            Write-Host "(x) An error occured, memory haven't been changed" -ForegroundColor Red
        }
    }
}

Function Update-VMVCPU {
    <#
        .SYNOPSIS
            Change number of virtual cpu allocated on a virtual machine
        .EXAMPLE
            Update-VMVCPU -VMId <String> -NewVMVCPU <Int32>
        .INPUTS
            VirtuaMachine id
            VirtualMachine new number of vcpu
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
        [Int]$NewVMVCPU
    )

    Begin {
        Write-Host "(i) Readjustment of the number of VCPU..." -ForegroundColor Cyan
    }

    Process {
        Try {
            Get-VM -Id $VMId | Set-VMProcessor -Count $NewVMVCPU -PassThru | Out-Null
            Write-Host " "
            Write-Host "(/) Number of VCPU have been set to: $NewVMVCPU" -ForegroundColor Green
            Write-Host " "
        } 
        
        Catch {
            Write-Host "(x) An error occured, number of VCPU haven't been changed" -ForegroundColor Red
        }
    }
}

Function Add-VMDisk {
    <#
        .SYNOPSIS
            Add a new disk for a virtual machine
        .EXAMPLE
            Add-VMDisk -VMId <String> -VMDiskName <String> -VMDiskSize <Int32>
        .INPUTS
            VirtuaMachine id
            New disk name
            New disk size
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
        [String]$DiskSize
    )

    Begin {
        Write-Host "(i) Disk will be created ..." -ForegroundColor Cyan
        $VMName = Get-VM -Id $VMId | Select-Object Name
        $VMName = $VMName.Name

        $VMDiskName += ".vhdx"
        $DiskPath = "'"+"$Global:DiskPath\$VMDiskName"+"'"
    }

    Process {
        Try {
            $Command = "New-VHD -Path $DiskPath -SizeBytes $DiskSize | Out-Null"
            Invoke-Expression $Command
            Write-Host "(/) Disk $VMDiskName have been created" -ForegroundColor Green
            Write-Host " "
            Write-Host "(i) Disk will be attached to the VM ..." -ForegroundColor Cyan
            $Command = "Get-VM VM02 | Add-VMHardDiskDrive -ControllerType SCSI -ControllerNumber 0 -Path $DiskPath"
            Invoke-Expression $Command
            Write-Host "(/) Disk have been added to the VM: $VMName" -ForegroundColor Green
            Write-Host " "
            Write-Host "DISK OF THE CURRENT VM :" -ForegroundColor Cyan
            Get-VMHardDiskDrive -VMName VM02
        }

        Catch {
            Write-Host "(x) An error occured, disk size haven't been modify" -ForegroundColor Red
        }
    }
}

Function Dismount-VMDisk {
    <#
        .SYNOPSIS
            Delete a disk for a virtual machine
        .EXAMPLE
            Dismount-VMDisk -VMId <String> -VMDiskName <String>
        .INPUTS
            VirtuaMachine id
            Disk name
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
        [String]$VMDiskName
    )

    Begin {
        Write-Host " "
        Write-Host "(i) Disk will be removed from the VM ..." -ForegroundColor Cyan
        $VMName = Get-VM -Id $VMId | Select-Object Name
        $VMName = $VMName.Name

        $ControllerValue = Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -like "*$VMDiskname" | Select-Object ControllerLocation
    }

    Process {
        Try {
            $ControllerValue = Get-VMHardDiskDrive -VMName $VMName | Where-Object Path -like "*$VMDiskname" | Select-Object ControllerLocation
            Remove-VMHardDiskDrive -VMName VM02 -ControllerType SCSI -ControllerNumber 0 -ControllerLocation $ControllerValue.ControllerLocation
            Write-Host "(/) Disk have been removed from the VM $VMName" -ForegroundColor Green
            Write-Host " "
        }

        Catch {
            Write-Host "(x) An error occured, the disk haven't been removed from the VM" -ForegroundColor Red 
        }
    }
}

Export-ModuleMember -Function Dismount-VMDisk, Add-VMDisk, Update-VMVCPU, Update-VMMemory
