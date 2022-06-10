
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
        $DiskList = Get-VMHardDiskDrive * -ComputerName $VirtualizationServerName

        Foreach($Disk in $DiskList) {
            If($Disk.Path -eq $VMDisk) {
                Return "NA"
            } Else {
                Write-Host "Deployment of a new virtual machine started..." -ForegroundColor Cyan
                Return $VMDisk
            }
        }
    }
}

Function Save-Configuration {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$VMName,
        [Parameter(Mandatory=$true)]
        [String]$VMRam,
        [Parameter(Mandatory=$true)]
        [String]$VMDisk,
        [Parameter(Mandatory=$true)]
        [String]$VMDiskSize,
        [Parameter(Mandatory=$true)]
        [String]$VMLocation,
        [Parameter(Mandatory=$true)]
        [Int16]$VMGeneration,
        [Parameter(Mandatory=$true)]
        [String]$VMIso,
        [Parameter(Mandatory=$true)]
        [String]$ServerName,
        [Parameter(Mandatory=$true)]
        [String]$VMSwitchName,
        [Parameter(Mandatory=$true)]
        [String]$VirtualizationServer
    )

    Begin {
        $Path = Get-VMDeploymentPath
    }

    Process {
        $VMDisk = $VMDisk.Replace('"', '')
        $VMLocation = $VMLocation.Replace('"', '')
        $VMIso = $VMIso.Replace('"', '')
        $VMSwitchName = $VMSwitchName.Replace('"', '')

        $VMValues = [PSCustomObject]@{
            Name = $VMName
            Ram = $VMRam
            DiskLocation = $VMDisk
            DiskSize = $VMDiskSize
            Location = $VMLocation
            Generation = $VMGeneration
            Iso = $VMIso
            SwitchName = $VMSwitchName
            ServerName = $VirtualizationServer
        }

        $VMConfig = [PSCustomObject]@{
            $VMName = $VMValues
        }

        $VMName = "$VMName"+".json"

        $ConfigPath = "$Path\Configuration\VirtualMachines" + "\$VMName"

        $VMLocation = '"'+$VMLocation+'"'

        $VMConfig | ConvertTo-Json -Depth 2 | Out-File $ConfigPath
    }
}

Function Get-AvailableIso {
        $shareServer = hostname
        $isoPath = "\\$shareServer\IsoFiles"

        Set-Location $isoPath

        $IsoList = @()

        ((ls -Path $Path).FullName) | ForEach-Object {
            $IsoList += $_
        }

        $IsoList = ConvertTo-Json -InputObject $IsoList

        Return $IsoList      
}

Function Add-NewVM {
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [String]$VMName,
        [Parameter(Mandatory=$true)]
        [String]$VMRam,
        [Parameter(Mandatory=$true)]
        [String]$VMDiskSize,
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
            $VMDisk = "C:\EasyCloud\VirtualMachines\Disk\$VMName" + ".vhdx"
            $DiskChecker = Find-DiskExistence -VMDisk $VMDisk -VirtualizationServerName $VirtualizationServer
            $VMPath = "C:\EasyCloud\VirtualMachines\VM\$VMName"
            $VMGeneration = 1
            $VMSwitchName = "InternalSwitch"
            $MachineCores = (Get-WmiObject Win32_processor -ComputerName $VirtualizationServer | Select-Object NumberOfLogicalProcessors)

            Write-Host $DiskChecker

            If($DiskChecker -eq "NA") {
                Write-Warning "Disk with same name already exist"
                Write-Host "(x) Deployment failed" -ForegroundColor Red
                Break;
            }

            If($VMProcessor -gt $MachineCores.NumberOfLogicalProcessors) {
                Write-Warning "Number of virtual cores attributed are outpassing physical server number"
                Write-Host "(x) Deployment failed" -ForegroundColor Red
                Break;
            }

            If(Get-VMSwitch -ComputerName $VirtualizationServer | Where-Object Name -like InternalSwitch) {
                Write-Host "InternalSwitch exist" -ForegroundColor Green
            } Else {
                New-VMSwitch -name 'InternalSwitch'  -NetAdapterName Ethernet -AllowManagementOS $true -ComputerName $VirtualizationServer
            }

            $Command = "New-VM -Name $VMName -ComputerName $VirtualizationServer -MemoryStartupBytes $VMRam -NewVHDPath '$VMDisk' -NewVHDSizeBytes $VMDiskSize -Path "+ "'$VMPath' " + "-Generation $VMGeneration -SwitchName '$VMSwitchName'"

            Write-Host "$Command"

            Invoke-Expression $Command
            
            Write-Host "------"

            Try {
                Add-VMDvdDrive -VMName $VMName -Path "$SelectedIsoPath" -ComputerName $VirtualizationServer
                Set-VMProcessor $VMName -Count $VMProcessor -ComputerName $VirtualizationServer
                Write-Host "(/) Sucessful verification" -ForegroundColor Green
            } 
            
            Catch {
                Write-Warning "(x) Verification failed"
                Break;
            }

            Write-Host "(/) Sucessful deployment" -ForegroundColor Green
            
            Try {
                $Save = 'Save-Configuration -VMName $VMName -VMRam $VMRam -VMDisk "$VMDisk" -VMDiskSize $VMDiskSize -VMLocation "$VMPath" -VMGeneration $VMGeneration -VMIso $VMOS -VMSwitchName $VMSwitchName'
                Invoke-Expression $Save
                Write-Host "(i) Configuration file have been saved in the following folder " -ForegroundColor Cyan -NoNewline
                Write-Host "$Path\Config" -BackgroundColor White -ForegroundColor DarkYellow
                Write-Host " "
            } Catch {
                Write-Warning "The configuration haven't been saved "
            }
        } 
        
        Catch {
            Write-Warning "An error occured in the execution"
            Write-Host "(x) Deployment failed" -ForegroundColor Red
        } 
    }
}

Function Uninstall-VM {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$VMId,
        [Parameter(Mandatory=$true)]
        [String]$VirtulizationServer
    )

    Process {
        Try {
            $VMPathToDelete = ((Get-VM -ComputerName $VirtulizationServer | Where-Object {$_.Name -like $VMName} | Select-Object HardDrives).HardDrives).Path
            Invoke-Command -ScriptBlock {Remove-Item -Path $VMPathToDelete} -ComputerName $VirtulizationServer
            Write-Host "Virtual machine named $VMName have been deleted on $VirtualizationServer" -ForegroundColor Green
        } Catch {
            Write-Error "A problem occured during the deletion"
        }
    }
}

Export-ModuleMember -Function Add-NewVM, Uninstall-VM, Get-AvailableIso
