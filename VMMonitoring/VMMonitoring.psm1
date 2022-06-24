$ConfPath = $PSScriptRoot+"\Configuration.json"

If((Test-Path $ConfPath) -eq $False) {
    New-Item -Path $ConfPath -ItemType File
    $json = "{

}" | Out-File $ConfPath
}

Function Get-MonitoringMode {
    <#
        .SYNOPSIS
            Return if monitoring is enabled or not
        .EXAMPLE
            Get-MonitoringMode -VMId c885c954-b9d0-4f58-a3a0-19cf21ea7980
        .INPUTS
            String
        .OUTPUTS
            Boolean
        .NOTES
            Function called on virtual machine details page on app
        .LINK
            https://github.com/Goldenlagen/EasyCloud_PSModules/tree/main#vmdeployment
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
