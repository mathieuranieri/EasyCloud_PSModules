Function Uninstall-EasyCloud {
    Process {
        Try {
            $Folder = (Get-Location).Path
            
            $moduleFolder = ";$Folder\App\Modules"
            $moduleFolder = $moduleFolder.replace(" ","")

            $str = $env:PSModulePath
            $str.Contains($moduleFolder)

            Remove-SmbShare -Name Iso
            
            If($str.Contains($moduleFolder)) {
                $str = $str.replace($moduleFolder, $null)

                [Environment]::SetEnvironmentVariable("PSModulePath", $str, "Machine")
            }

            Remove-Item -Path "$Folder\App"
            Remove-Item -Path "$Folder\Configuration"

        } Catch {
            Write-Error "Error"
        }
    }
}

Uninstall-EasyCloud