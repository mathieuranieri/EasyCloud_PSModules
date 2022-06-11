Function Uninstall-EasyCloud {
    Process {
        Try {
            $Folder = $PSScriptRoot
            
            
            $moduleFolder = ";$Folder\App\Modules"
            $moduleFolder = $moduleFolder.replace(" ","")

            Write-Host $moduleFolder
            Read-Host "Waiting"      
        
            Remove-SmbShare -Name Iso

        
            $str = $env:PSModulePath

            If($str.Contains($moduleFolder)) {
                $str = $str.replace($moduleFolder, $null)

                [Environment]::SetEnvironmentVariable("PSModulePath", $str, "Machine")
            }

            Remove-Item -Path $Folder
        } Catch {
            Write-Error "Error"
        }
    }
}

Uninstall-EasyCloud