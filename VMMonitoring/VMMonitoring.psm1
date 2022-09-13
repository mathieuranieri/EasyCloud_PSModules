
$ConfPath = $PSScriptRoot+"\Configuration.json"

If((Test-Path $ConfPath) -eq $False) {
    New-Item -Path $ConfPath -ItemType File
    $json = "{

    }" | Out-File $ConfPath
}

Function Get-MonitoringMode {
    <#
        .SYNOPSIS
            Retrieve the monitoring mode of a virtual machine
        .EXAMPLE
            Get-MonitoringMode -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980
        .DESCRIPTION
            Retrieve the monitoring mode of a virtual machine
        .NOTES
            Function called on virtual machine details page on app
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMMonitoring
    #>
    Param(
        [Parameter(Mandatory)]
        $VMId
    )

    Process {
        $Data = Get-Content $ConfPath | ConvertFrom-Json
        Return $Data.$VMId
    }
}

Function Update-MonitoringMode {
    <#
        .SYNOPSIS
            Change monitoring mode to true or false and return confirmation
        .EXAMPLE
            Update-MonitoringMode -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -isMonitored $True -VirtualizationServer VMSRV01
        .INPUTS
            ID of a virtual machine
            Monitoring value as true or false
            Name  of a virtualization server
        .OUTPUTS
            Confirmation message
        .DESCRIPTION
            This function will update the configuration file, set true or false the monitoring mode for the provided
            virtual machine name and it will enable ressource metering on true and disable resource metering on false
        .NOTES
            Function called on virtual machine details page on app when button monitoring on/off is activated
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMMonitoring
    #>
    Param(
        [Parameter(Mandatory)]
        $VMId,
        [Parameter(Mandatory)]
        [ValidateSet($false, $true, 0, 1)]
        $isMonitored,
        [Parameter(Mandatory)]
        $VirtualizationServer
    )

    Process { 
        $VMName = (Get-VM -Id $VMId -ComputerName $VirtualizationServer).Name
        $Data = Get-Content $ConfPath | ConvertFrom-Json

        If($null -ne $Data.$VMId) {
            $Data.$VMId = $isMonitored
        } Else {
            $Data | Add-Member  @{$VMId = $isMonitored}
        }

        If($Data.$VMId) {
            Enable-VMResourceMetering -VMName $VMName -ComputerName $VirtualizationServer
        } 
        
        Else {
            Disable-VMResourceMetering -VMName $VMName -ComputerName $VirtualizationServer
        }

        $Data | ConvertTo-Json | Out-File $ConfPath

        Return "Monitoring have been set to $isMonitored for VirtualMachine $VMName"
    }
}

Function Get-MonitoringData {
    <#
        .SYNOPSIS
            Retrieving monitoring data (CPU, RAM, Disk) to display in app graph
        .EXAMPLE
            Get-MonitoringData -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980 -VirtualizationServer VMSRV01
        .INPUTS
            ID of a virtual machine
            Name  of a virtualization server
        .OUTPUTS
            String data formated into JSON
        .DESCRIPTION
            This function will collect monitoring data, cpu, ram, disk by using measure vm command it will format the
            output as a JSON
        .NOTES
            Function called every n seconds when on virtual machine details page and monitoring is activated
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main/VMMonitoring
    #>
    Param(
        [Parameter(Mandatory)]
        $VMId,
        [Parameter(Mandatory)]
        $VirtualizationServerName
    )

    Process {
        $Config = Get-Content $ConfPath | ConvertFrom-Json
        $VMName = (Get-VM -Id $VMId -ComputerName $VirtualizationServerName).Name 

        If($Config.$VMId) {
            Return (Measure-VM -VMName $VMName -ComputerName $VirtualizationServerName | Select-Object VMName, AvgRam, VMId, AvgCPU, TotalDisk | ConvertTo-Json)
        }

        Else {
            Return "Monitoring disabled"
        }
    }
}

Export-ModuleMember -Function Update-MonitoringMode, Get-MonitoringData, Get-MonitoringMode
