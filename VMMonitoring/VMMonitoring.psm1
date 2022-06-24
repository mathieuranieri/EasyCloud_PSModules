$ConfPath = $PSScriptRoot+"\Configuration.json"

If((Test-Path $ConfPath) -eq $False) {
    New-Item -Path $ConfPath -ItemType File
    $json = "{

}" | Out-File $ConfPath
}

Function Get-MonitoringMode {
    <#
        .SYNOPSIS
            Tells if monitoring is enabled or not
        .EXAMPLE
            Get-MonitoringMode -VMId <String>
        .INPUTS
            ID of a virtual machine
        .OUTPUTS
            Monitoring value as true or false
        .NOTES
            Function called on virtual machine details page on app
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmmonitoring
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
            Update-MonitoringMode -VMId <String> -isMonitored <Boolean> -ServerName <String>
        .INPUTS
            ID of a virtual machine
            Monitoring value as true or false
            Name  of a virtualization server
        .OUTPUTS
            Confirmation message
        .NOTES
            Function called on virtual machine details page on app when button monitoring on/off is activated
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmmonitoring
    #>
    Param(
        [Parameter(Mandatory)]
        $VMId,
        [Parameter(Mandatory)]
        [ValidateSet($false, $true, 0, 1)]
        $isMonitored,
        [Parameter(Mandatory)]
        $ServerName
    )

    Process { 
        $VMName = (Get-VM -Id $VMId -ComputerName $ServerName).Name
        $Data = Get-Content $ConfPath | ConvertFrom-Json

        If($null -ne $Data.$VMId) {
            $Data.$VMId = $isMonitored
        } Else {
            $Data | Add-Member  @{$VMId = $isMonitored}
        }

        If($Data.$VMId) {
            Enable-VMResourceMetering -VMName $VMName -ComputerName $ServerName
        } 
        
        Else {
            Disable-VMResourceMetering -VMName $VMName -ComputerName $ServerName
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
            Get-MonitoringData -VMId <String> -ServerName <String>
        .INPUTS
            ID of a virtual machine
            Name  of a virtualization server
        .OUTPUTS
            String data formated into JSON
        .NOTES
            Function called every n seconds when on virtual machine details page and monitoring is activated
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmmonitoring
    #>
    Param(
        [Parameter(Mandatory)]
        $VMId,
        [Parameter(Mandatory)]
        $ServerName
    )

    Process {
        $Config = Get-Content $ConfPath | ConvertFrom-Json
        $VMName = (Get-VM -Id $VMId -ComputerName $ServerName).Name 

        If($Config.$VMId) {
            Return (Measure-VM -VMName $VMName -ComputerName $ServerName | Select-Object VMName, AvgRam, VMId, AvgCPU, TotalDisk | ConvertTo-Json)
        }

        Else {
            Return "Monitoring disabled"
        }
    }
}

Export-ModuleMember -Function Update-MonitoringMode, Get-MonitoringData, Get-MonitoringMode
