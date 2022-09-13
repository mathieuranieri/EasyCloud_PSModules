# EasyCloud PowerShell Modules

_This repository contains all powershell modules used in EasyCloud Application the modules listed below are used with a Backend Server but they can be used manually_

>Required : powershell.exe


## Summary
---
- [Summary](#summary)
    - [EasyCloud Modules](#easycloud-modules)
        - [Contextualization](#contextualization)
        - [VMDeployment](#vmdeployment)
        - [VMMonitoring](#vmmonitoring)
        - [VMConfiguration](#vmconfiguration)

## EasyCloud Modules
---
### Contextualization
The PowerShell modules for this project are used with a backend server NodeJS. These modules will have for role the management of Virtual Machines on a On-Premise environment, Hyper-V is used as a basis. The functionalities of the modules are the following :
- Deployment of a virtual machine
- Monitoring of a virtual machine
- Configuration of a virtual machine

### VMDeployment
---
Module : [VMDeployment.psm1](./VMDeployment/VMDeployment.psm1)

>- Create new virtual machine
>- Uninstall virtual machine
>- Retrieving ISO Files for a virtual machine

Usage :
```powershell
Add-NewVM -VMName "VirtualMachine01" -VMRAM 2GB -VMDiskSize 50GB -VMOS "\\EASYCLOUD-APP\Iso\Win2016.Iso" -VMProcessor 1 -VirtualizationServer "VMSRV01"
```
```powershell
Get-AvailableIso
```
```powershell
Uninstall-VM -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -VirtualizationServer "VMSRV01"
```

### VMMonitoring
---
Module : [VMMonitoring.psm1](./VMMonitoring/VMMonitoring.psm1)

>- Define the monitoring status of a virtual machine
>- Retrieving monitoring data from a virtual machine
>- Get the moniroting status of a virtual machine

Usage :
```powershell
Update-MonitoringMode -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -isMonitored $True -VirtualizationServer "VMSRV01"
```
```powershell
Get-MonitoringData -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -VirtualizationServer "VMSRV01"
```
```powershell
Get-MonitoringMode -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980"
```

### VMConfiguration
---
Module : [VMConfiguration.psm1](./VMConfiguration/VMConfiguration.psm1)

>- Modifying number of virtual processor for a virtual machine
>- Modifying number of ram allocated for a virtual machine
>- Mount & Dismount virtual disk on a virtual machine


Usage :
```powershell
Update-VMMemory -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -NewVMRam 2GB -VirtualizationServer VMSRV01
```
```powershell
Update-VMVCPU  -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -NewVMVCPU 4 -VirtualizationServer VMSRV01
```
```powershell
Add-VMDisk -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -DiskName "MyDisk" -DiskSize 100GB -VirtualizationServer VMSRV01
```
```powershell
Dismount-VMDisk -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -DiskName "MyDisk" -VirtualizationServer VMSRV01
```
