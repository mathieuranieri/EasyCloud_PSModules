
Function Convert-Size {            
    [cmdletbinding()]          
    Param(            
        [ValidateSet("Bytes","KB","MB","GB","TB")]            
        [String]$From,

        [ValidateSet("Bytes","KB","MB","GB","TB")]      
        [String]$To, 

        [Parameter(Mandatory=$true)]           
        [Double]$Value           
    )

    Switch($From) {            
        "Bytes" {$value = $Value }            
        "KB" {$value = $Value * 1024 }            
        "MB" {$value = $Value * 1024 * 1024}            
        "GB" {$value = $Value * 1024 * 1024 * 1024}            
        "TB" {$value = $Value * 1024 * 1024 * 1024 * 1024}            
    }            
                
    Switch ($To) {            
        "Bytes" {return $value}            
        "KB" {$Value = $Value/1KB}            
        "MB" {$Value = $Value/1MB}            
        "GB" {$Value = $Value/1GB}            
        "TB" {$Value = $Value/1TB}            
                
    }            
                
    return [Math]::Round($value,4,[MidPointRounding]::AwayFromZero)            
                
}   

Function Get-VMStatus {
    <#
        .SYNOPSIS
        Display information about an existing virtual machine

        .DESCRIPTION
        Display information about an existing virtual machine
        Retrieving information by providing a VM Id and the virtualization server name

        .INPUTS
        Return VM Status data if worked else return NOK status

        .EXAMPLE
        PS> Get-VMStatus -VMId a1u2g-3f8jk-1bnps-ajfj2 -VirtualizationServerName VMSRV01

        .LINK
        https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMConfiguration
    #>  
    Param(
        [Parameter(Mandatory)]
        #Provide the Hyper-V virtual machine Id
        [String]$VMId,

        [Parameter(Mandatory)]
        #Provide the server name where the VM is located at
        [String]$VirtualizationServerName
    )

    Process {
        Try {
            $VMStatus = New-Object System.Collections.ArrayList

            $VM = Get-VM -ComputerName $VirtualizationServerName -Id $VMId 
            $Disk = $VM | Get-VMHardDiskDrive | Get-VHD -ComputerName $VirtualizationServerName #| Select-Object FileSize, Size

            $DiskList = New-Object System.Collections.ArrayList

            $Disk | Foreach-Object {
                [String]$Size = (Convert-Size -From Bytes -To GB -Value $_.FileSize)
                [String]$MaxSize = (Convert-Size -From Bytes -To GB -Value $_.Size)

                $Size+="GB"
                $MaxSize+="GB"

                $DiskList.Add(@{
                    DiskName = $_.Path | Split-Path -Leaf
                    Path = $_.Path
                    Size =  $Size
                    MaxSize = $MaxSize
                }) | Out-Null
            }

            $Processor = $VM.ProcessorCount
            [String]$Ram = Convert-Size -From Bytes -To GB -Value $VM.MemoryStartup

            $Ram+= "GB"

            $VMStatus.Add(@{
                Disk = $DiskList
                Processor = $Processor
                Ram = $Ram
            }) | Out-Null

            Return $VMStatus | ConvertTo-Json
        }

        Catch {
            $_
            Return 'NOK'
        }
    }
}

Function Set-VMStatus {
    <#
        .SYNOPSIS
        Put ON or OFF a virtual machine

        .DESCRIPTION
        Put ON or OFF a virtual machine
        Provide a virtual machine a status and the virtualization server name

        .INPUTS
        None

        .OUTPUTS
        Return ON or OFF if worked else return NOK status

        .DESCRIPTION
        Put ON or OFF a virtual machine
        Set to ON or OFF a virtual machine by providing an Id a Status and the Virtualization server name

        .EXAMPLE
        PS> Set-VMStatus -VMId a1u2g-3f8jk-1bnps-ajfj2 -VMStatus ON -VirtualizationServerName VMSRV01

        .LINK
        https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMConfiguration
    #> 
    Param(
        [Parameter(Mandatory)]
        #Provide the Hyper-V virtual machine Id
        [String]$VMId,

        [Parameter(Mandatory)]
        #Provide the state that will be set the to the virtual machine
        [ValidateSet('ON', 'OFF')]
        [String]$VMStatus,

        [Parameter(Mandatory)]
        #Provide the virtualization server name where the VM is located at
        [String]$VirtualizationServerName
    )

    Process {
        Try {
            If($VMStatus -eq 'ON') {
                Get-VM -ComputerName $VirtualizationServerName -Id $VMId | Start-VM
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
            Update the memory allocated to a virtual machine
        
        .DESCRIPTION
            Update the memory allocated to a virtual machine
            Provide a virtual machine Id, new ram number allocated and the virtualization server
        
        .INPUTS
            None

        .OUTPUTS
            Return OK status else return NOK status

        .EXAMPLE
            PS> Update-VMMemory -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -NewVMRam 2GB -VirtualizationServer VMSRV01

        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMConfiguration
    #>
    Param(
        [Parameter(Mandatory)]
        #Provide the Hyper-V virtual machine Id
        [String]$VMId,

        [Parameter(Mandatory)]
        #Provide the new ram number that will be allocated to the virtual machine
        [UInt64]$NewVMRam,

        [Parameter(Mandatory)]
        #Provide the virtualization server where the virtual machine is located at
        [String]$VirtualizationServerName
    )

    Process {
        Try {
            $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServerName
            $VM | Set-VMMemory -StartupBytes $NewVMRam
            Return "OK"
        } 
        
        Catch {
            Return "NOK"
        }
    }
}

Function Update-VMVCPU {
    <#
        .SYNOPSIS
            Update the number of virtual cores allocated to a virtual machine
        
        .DESCRIPTION
            Update the number of virtual cores allocated to a virtual machine
            Provide a virtual machine Id, the number of v-cpu that will be allocated and the virtualization server name

        .INPUTS
            None
            
        .OUTPUTS
            Return OK else return NOK

        .EXAMPLE
            PS> Update-VMVCPU -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -NewVMVCPU 2 -VirtualizationServer VMSRV01

        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMConfiguration
    #>
    Param(
        [Parameter(Mandatory)]
        #Provide the Hyper-V virtual machine Id
        [String]$VMId,

        [Parameter(Mandatory)]
        #Provided the number of V-CPU that will be allocated
        [Int]$NewVMVCPU,

        [Parameter(Mandatory)]
        #Provide the virtualization server name where the virtual machine machine is located at
        [String]$VirtualizationServerName
    )

    Process {
        Try {
            $VM = Get-VM -Id $VMId -ComputerName $VirtualizationServerName
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

Function Expand-VMDiskSize {
    <#
        .SYNOPSIS
            Expands the maximum authorized size of a virtual disk attached located on a virtualization server
        
        .DESCRIPTION
            Expands the maximum authorized size of a virtual disk attached located on a virtualization server
            Provide a virtual disk path, the virtualization server name and the new maximum size

        .INPUTS
            None
            
        .OUTPUTS
            Return OK else return NOK

        .EXAMPLE
            PS> Expand-VMDiskSize -DiskPath C:\EasyCloud\VirtualMachine\Disk\Disk01.vhdx -VirtualizationServer VMSRV01 -SetMaxSize 100GB

        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMConfiguration
    #>
    Param (
        [Parameter(Mandatory)]
        #Virtual disk path on the provided virtualization server
        [String]$DiskPath,

        [Parameter(Mandatory)]
        #Provide the target virtualization server name
        [String]$VirtualizationServerName,

        [Parameter(Mandatory)]
        #Provide the new maximum size that will be set for the virtual disk
        [UInt64]$SetMaxSize
    )

    Process {
        Try {
            Resize-VHD -Path $DiskPath -ComputerName $VirtualizationServerName -SizeBytes $SetMaxSize -ErrorAction Stop
            Return 'OK'
        }
        
        Catch {
            Return 'NOK'
        }
    }
}

Function Add-VMDisk {
    <#
        .SYNOPSIS
            Attach a new virtual disk to a virtual machine
        
        .DESCRIPTION
            Attach a new virtual disk to a virtual machine
            Create a new virtual disk and attach it the a virtual machine by providing the Id of it 
            and the disk name and size and the virtualization server the virtual machine is located at
        
        .INPUTS
            None

        .OUTPUTS
            Return OK else return NOK

        .EXAMPLE
            Add-VMDisk -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VMDiskName "Disk01" -VMDiskSize 30GB -VirtualizationServer VMSRV01

        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMConfiguration
    #>
   Param(
        [Parameter(mandatory=$true)]
        #Provide an Hyper-V virtual machine Id
        [String]$VMId,

        [Parameter(mandatory=$true)]
        #Provide the name of the new virtual disk
        [String]$VMDiskName,

        [Parameter(mandatory=$true)]
        #Provide the new maximum size of the virtual disk
        [UInt64]$DiskSize,

        [Parameter(mandatory=$true)]
        #Provide the virtualization server name where the virtual machine is located at
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

                Return "NOK"
            }
        }

        Catch {
            Return "NOK"
        }
    }
}

Function Dismount-VMDisk {
    <#
        .SYNOPSIS
            Detach and delete a disk from a virtual machine
        
        .DESCRIPTION
            Detach and delete a disk from a virtual machine
            Take the virtual machine Id, the disk name and the virtualization server name
        
        .EXAMPLE
            PS> Dismount-VMDisk -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VMDiskName "Disk01" -VirtualizationServer VMSRV01
        
        .INPUTS
           None

        .OUTPUTS
            Return OK else return NOk

        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMConfiguration
    #>
    Param(
        [Parameter(mandatory=$true)]
        #Provide an Hyper-V virtual machine Id
        [String]$VMId,

        [Parameter(mandatory=$true)]
        #Provide the diskname attached the provided virtual machine
        [String]$VMDiskName,

        [Parameter(mandatory=$true)]
        #Provide the server name where the virtual machine is located at
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
    <#
        .SYNOPSIS
            Get a virtual machine attached disks 
        
        .DESCRIPTION
            Get a virtual machine attached disks 
            Take the virtual machine Id and a virtualization server name
        
        .EXAMPLE
            PS> Get-VMAttachedDrives -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VirtualizationServer VMSRV01
        
        .INPUTS
           None

        .OUTPUTS
            Return disk list an array of object else return NOK

        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMConfiguration
    #>
    Param(
        [Parameter(mandatory=$true)]
        #Provide an Hyper-V virtual machine Id
        [String]$VMId,

        [Parameter(mandatory=$true)]
        #Provide a virtualization server name where the virtual machine is located at
        [String]$VirtualizationServer
    )

    Process {
        Try {
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

        Catch {
            Return 'NOK'
        }
    }
}

Export-ModuleMember -Function Dismount-VMDisk, Add-VMDisk, Update-VMVCPU, Update-VMMemory, Get-VMAttachedDrives, Set-VMStatus, Get-VMStatus, Expand-VMDiskSize 
