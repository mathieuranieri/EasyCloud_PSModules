
Function Set-VMStatus {
    Param(
        [Parameter(Mandatory)]
        [String]$VMId,

        [Parameter(Mandatory)]
        [ValidateSet('ON', 'OFF')]
        [String]$VMStatus,

        [Parameter(Mandatory)]
        [String]$VirtualizationServerName
    )

    Process {
        Try {
            If($VMStatus -eq 'ON') {
                Get-VM -ComputerName $VirtualizationServerName -Id $VMId | Start-VM -Force
                Return 'ON'
            }

            ElseIf($VMStatus -eq 'OFF') {
                Get-VM -ComputerName $VirtualizationServerName -Id $VMId | Stop-VM -Force
                Return 'OFF'
            }
        }

        Catch {
            Return 'NOK'
        }
    }
}

Function Update-VMMemory {
    <#
        .SYNOPSIS
            Change memory allocated on a virtual machine
        .EXAMPLE
            Update-VMMemory -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -NewVMRam 2GB -VirtualizationServer VMSRV01
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
        $NewVMRam,
        [Parameter(mandatory=$true)]
        [String]$VirtualizationServer
    )

    Process {
        Try {
            $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServer
            $VM | Set-VMMemory -StartupBytes $NewVMRam
            Return "OK"
        } 
        
        Catch {
            $_
            Return "NOK"
        }
    }
}

Function Update-VMVCPU {
    <#
        .SYNOPSIS
            Change number of virtual cpu allocated on a virtual machine
        .EXAMPLE
            Update-VMVCPU -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -NewVMVCPU 2 -VirtualizationServer VMSRV01
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
        [String]$VirtualizationServer
    )

    Process {
        Try {
            $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServer
            $Cores = (Get-WmiObject -Class WIn32_Processor).NumberOfLogicalProcessors

            If($NewVMVCPU -gt ($Cores / 2)) {
                Return "LIMIT"
            }

            $VM | Set-VMProcessor -Count $NewVMVCPU
            Return "OK"
        } 
        
        Catch {
            Return "NOK"
        }
    }
}

Function Add-VMDisk {
    <#
        .SYNOPSIS
            Add a new disk for a virtual machine
        .EXAMPLE
            Add-VMDisk -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VMDiskName "Disk01" -VMDiskSize 30GB -VirtualizationServer VMSRV01
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
        [UInt64]$DiskSize,
        [Parameter(mandatory=$true)]
        [String]$VirtualizationServer
    )

    Begin {
        $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServer
        $VMName = $VM.Name
        $DiskName = $VMDiskName+".vhdx"
    }

    Process {
        Try {
            $DiskPath = "C:\EasyCloud\VirtualMachines\Disk\$DiskName"
            New-VHD -Path $DiskPath -SizeBytes $DiskSize -ComputerName $VirtualizationServer | Out-Null
            Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -Path $DiskPath -ComputerName $VirtualizationServer

            If(($VM | Get-VMHardDiskDrive).Path -eq $DiskPath) {
                Return "OK"
            } Else {
                Invoke-Command -ComputerName $VirtualizationServer {
                    param($Path)
                    Remove-Item -Path $Path
                } -ArgumentList $DiskPath

                Write-Host 'Test'
                Return "NOK"
            }
        }

        Catch {
            $_
            Return "NOK"
        }
    }
}

Function Dismount-VMDisk {
    <#
        .SYNOPSIS
            Delete a disk for a virtual machine
        .EXAMPLE
            Dismount-VMDisk -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VMDiskName "Disk01" -VirtualizationServer VMSRV01
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
        [String]$VirtualizationServer
    )

    Begin {
        $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServer
        $VMName = $VM.Name
    }

    Process {
        Try {
            $VMDiskPath = "C:\EasyCloud\VirtualMachines\Disk\$VMDiskName"+".vhdx"
            $ControllerValue = Get-VMHardDiskDrive -VMName $VMName -ComputerName $VirtualizationServer | Where-Object Path -eq "$VMDiskPath"
            $ControllerValue | Remove-VMHardDiskDrive

            If($null -eq ($VM | Get-VMHardDiskDrive | Where-Object Path -eq $VMDiskPath).Path) {
                Invoke-Command -ComputerName $VirtualizationServer {
                    param($Path)
                    Remove-Item -Path $Path
                } -ArgumentList $VMDiskPath

                Return "OK" 
            }

            Else {
                Return "NOK"
            }
        }

        Catch {
            Return "NOK"
        }
    }
}

Function Get-VMAttachedDrives {
    Param(
        [Parameter(mandatory=$true)]
        [String]$VMId,
        [Parameter(mandatory=$true)]
        [String]$VirtualizationServer
    )

    Process {
        $DiskList = New-Object System.Collections.ArrayList

        $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServer
        $Disk = ($VM | Get-VMHardDiskDrive).Path

        $Disk | ForEach-Object {
            $DiskList.Add(@{
                "vmId" = $VMId 
                "disk" = "$_" 
            }) | Out-Null    
        }

        $DiskList = ConvertTo-Json -InputObject $DiskList

        Return $DiskList   
    }
}

Export-ModuleMember -Function Dismount-VMDisk, Add-VMDisk, Update-VMVCPU, Update-VMMemory, Get-VMAttachedDrives, Set-VMStatus
