﻿Function Read-MonitoringMode {
    Param(
        [Parameter(Mandatory=$True)]
        $VMList
    )

    Begin {
        $GetMonitoringMode = (Get-Content "F:\ESTIAM\M1 - ESTIAM\PIM\Scripts\App\PSScripts\MonitoringInfo.json" | ConvertFrom-Json).MonitoringMode
        If($GetMonitoringMode) {
            Write-Host "Monitoring informations will be retrieved..." -ForegroundColor Green
            $IsMonitored = @()
        } Else {
            Return "Off"
        }

    }

    Process {
        $VMList | ForEach-Object {
            $IsMonitored += New-Object -TypeName psobject -Property @{VMName=$_; isMonitored=(Get-VM -Name $_ | Select-Object ResourceMeteringEnabled).ResourceMeteringEnabled}
        }

        Return $IsMonitored
    }
}

Function Enable-VMMonitoring {
    Param(
        [Parameter(Mandatory=$True)]
        $VMName
    )

    Begin {
        $Error.Clear()
        If((Read-MonitoringMode -VMList (Get-VM).Name) -eq "Off") {
            Write-Host "Global Monitoring mode is set to OFF, if you want to use it on all Virtual Machine set it to ON" -ForegroundColor Yellow
            Break;
        }
    }

    Process {
        $Answer = Read-Host "Do you want enable monitoring for the Virtual Machine: $VMName ? (Y/N)"
        If($Answer -eq "Y") {
            Enable-VMResourceMetering -VMName $VMName
            Clear-Host;

            If($Error) {
                Write-Host "An error occurred during monitoring activation for $VMName"
                Break;
            } Else {
                Write-Host "Monitoring have been enabled for Virtual Machine: $VMName" -ForegroundColor Green
                Read-MonitoringMode -VMList (Get-VM).Name
            }
            
        } Else {
            Write-Warning "Monitoring won't be activated for Virtual Machine: $VMName"
        }
    }
}

Function Disable-VMMonitoring {
    Param(
        [Parameter(Mandatory=$True)]
        $VMName
    )

    Begin {
        $Error.Clear()
        If((Read-MonitoringMode -VMList (Get-VM).Name) -eq "Off") {
            Write-Host "Global Monitoring mode is set to OFF, if you want to use it on all Virtual Machine set it to ON" -ForegroundColor Yellow
            Break;
        }
    }

    Process {
        $Answer = Read-Host "Do you want disable monitoring for the Virtual Machine: $VMName ? (Y/N)"
        If($Answer -eq "Y") {
            Disable-VMResourceMetering -VMName $VMName
            Clear-Host;

            If($Error) {
                Write-Host "An error occurred during monitoring disabling for $VMName"
                Break;
            } Else {
                Write-Host "Monitoring have been disabled for Virtual Machine: $VMName" -ForegroundColor Green
                Read-MonitoringMode -VMList (Get-VM).Name
            }
            
        } Else {
            Write-Warning "Monitoring won't be disabled for Virtual Machine: $VMName"
        }
    }
}

Function Get-MonitoringData {
    Param(
        [Parameter(Mandatory=$True)]
        $VMList
    )

    Begin {
        $VMListToMonitor = @()

        $VMList | ForEach-Object {
            If($_.isMonitored -eq $True) {
                $VMListToMonitor += $_.VMName
            }
        }
    }

    Process {
        Write-Host "Test"
        $VMListToMonitor | ForEach-Object {
           Measure-VM -Name $_ | ConvertTo-Json | Add-Content -Path "F:\ESTIAM\M1 - ESTIAM\PIM\Scripts\App\PSScripts\MonitoringData_$_.json"
        }
    }
}

Function Use-Monitoring {
    $isEnabled = Read-Host "Monitoring mode (ON/OFF)"

    If($isEnabled -eq "On") {
        Write-Host "Monitoring is enabled" -ForegroundColor Green
        @{MonitoringMode = $True} | ConvertTo-Json | Out-File "F:\ESTIAM\M1 - ESTIAM\PIM\Scripts\App\PSScripts\MonitoringInfo.json"
    } ElseIf($isEnabled -eq "OFF") {
        Write-Host "Monitoring is disabled" -ForegroundColor Green
        @{MonitoringMode = $False} | ConvertTo-Json | Out-File "F:\ESTIAM\M1 - ESTIAM\PIM\Scripts\App\PSScripts\MonitoringInfo.json"
    }
}

Export-ModuleMember -Function Use-Monitoring, Get-MonitoringData, Disable-VMMonitoring, Enable-VMMonitoring, Read-MonitoringMode
