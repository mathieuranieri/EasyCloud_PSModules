# EasyCloud PowerShell Modules

> _This repository contains all powershell modules used in EasyCloud Application the modules listed below are used with a Backend Server but they can be used manually_


## Summary
---
- [Summary](#summary)
    - [Good PowerShell practises](#good-practises)
        - [Starting with modules](#starting-with-modules)
        - [Creating modules](#creating-modules)
        - [Module functionalities](#module-functionalities)
    - [EasyCloud Modules](#easycloud-modules)
        - [Contextualization](#contextualization)
        - [VMDeployment](#vmdeployment)
        - [VMMonitoring](#vmmonitoring)
        - [VMConfiguration](#vmconfiguration)


## Good Practises

### Starting with modules
---
You can chose the name you want for a module. There is few things to take into account that are : 
- Your module have to be place in a **folder** that have **the same name** of it.
- Module extension is **.psm1**
- Module have to be created in dedicated folder, the list can be retrieved with this environment variable : 
```powershell
$Env:PSModulePath -Split ';'
```
- You are free to edit this environment variable to add your own module folder
- A PowerShell profile can be configured to execute commands on openning a new PowerShell session (by default not existing) for example to load modules :
```powershell
#Different profile
$Profile
$Profile.CurrentUserAllHosts
$Profile.AllUsersCurrentHost
$Profile.AllUsersAllHosts

#Create the profile
New-Item -Path $Profile -ItemType File -Force 
```
You can load a PowerShell modules with the following command :
```powershell
Import-Module Module1, Module2, ...
```
An other good practise is to create a PowerShell module manifest for our module it is a file describing the module and determine how the module will work the file extension is **.psd1**. Usefull to make versionning on our module and to configure it properly :
```powershell
New-ModuleManifest -Path ManifestPath.psd1 -RootModule MyModule
```

### Module functionalities
---
Powershell functions are named with the following syntax : **Verb-MyData**

To see which verb are authorised you can execute the following command :
```powershell
Get-Verb
```
When your module is created you can create funtion inside of it.
A function can be cut in different block :
- **Parameter** : configure parameter with many options
- **Begin** : containing code executed at the beginning of the execution
- **Process** : containing main code
- **End** : containing code executed at the end of the execution
```powershell
Function Verb-Data {
    Param(

    )

    Begin {

    }

    Process {

    }

    End {

    }
}
```
Then to export the functionalities so they can be used when module is imported:
```powershell
Export-ModuleMember MyFunction1, MyFunction2
```
To see if function are correctly exported you can check with:
```powershell
Get-Module -Name MyModule
```

### Module description
---
To provide the user a module documentation the following command can be used :
```powershell
Get-Help MyModuleFunctions -Full
```
It can be configured by adding following comment inside the function to explaine how it works :
```powershell
<#
.SYNOPSIS
    Short description here
.EXAMPLE
    Command example with output
.INPUTS
    Type of object in inputing
.OUTPUTS
    Type of object returned
.NOTES
    Some bonus informations
.LINK
    Help link for the function
#>
```

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
#Return confirmation message & Virtual Machine ID
```
```powershell
Get-AvailableIso
#Return JSON Data
```
```powershell
Uninstall-VM -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -VirtualizationServer "VMSRV01"
#Return confirmation Message
```

### VMMonitoring
---
Module : [VMMonitoring.psm1](./VMMonitoring/VMMonitoring.psm1)

>- Define the monitoring status of a virtual machine
>- Retrieving monitoring data from a virtual machine
>- Get the moniroting status of a virtual machine

Usage :
```powershell
Update-MonitoringMode -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -isMonitored $True -ServerName "VMSRV01"
#Return confirmation message
```
```powershell
Get-MonitoringData -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -ServerName "VMSRV01"
#Return JSON Data
```
```powershell
Get-MonitoringMode -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980"
#Return True / False
```

### VMConfiguration
---
Module : [VMConfiguration.psm1](./VMConfiguration/VMConfiguration.psm1)

>- Modifying number of virtual processor for a virtual machine
>- Modifying number of ram allocated for a virtual machine
>- Mount & Dismount virtual disk on a virtual machine


Usage :
```powershell
Update-VMMemory -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -NewVMRam 2GB
#Return confirmation message
```
```powershell
Update-VMVCPU  -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -NewVMVCPU 4
#Return confirmation message
```
```powershell
Add-VMDisk -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -DiskName "MyDisk" -DiskSize 100GB
#Return confirmation message
```
```powershell
Dismount-VMDisk -VMId "c885c954-b9d0-4f58-a3a0-19cf21ea7980" -DiskName "MyDisk"
#Return confirmation message
```