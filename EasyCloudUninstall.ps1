Function Uninstall-EasyCloud {
    Process {
        $Folder = $PSScriptRoot        
        
        Remove-SmbShare -Name Isofiles

        $moduleFolder = ";$Folder\App\Modules"
        $moduleFolder = $moduleFolder.replace(" ","")
        
        $str = $env:PSModulePath

        $str.Contains($moduleFolder)

        $str = $str.replace($moduleFolder, $null)

        [Environment]::SetEnvironmentVariable("PSModulePath", $str, "Machine")

        Remove-Item -Path $Folder
    }
}

Uninstall-EasyCloud