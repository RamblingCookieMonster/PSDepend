function Test-Dotnet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Version,
        
        [Parameter()]
        [string]
        $InstallDir
    )

    $dotnetFile = if ($IsWindowsEnv) { "dotnet.exe" } else { "dotnet" }

    if ($InstallDir) {
        $dotnetExePath = Join-Path -Path $InstallDir -ChildPath $dotnetFile
    } else {
        # If dotnet is already in the PATH, check to see if that version of dotnet can find the required SDK.
        # This is "typically" the globally installed dotnet.
        $dotnetInPath = Get-Command 'dotnet' -ErrorAction SilentlyContinue
        if ($dotnetInPath) {
            $dotnetExePath = $dotnetInPath.Source
        } else {
            $IsWindowsEnv = [RuntimeInformation]::IsOSPlatform([OSPlatform]::Windows)
            $LocalDotnetDirPath = if ($IsWindowsEnv) { "$env:LocalAppData\Microsoft\dotnet" } else { "$env:HOME/.dotnet" }
            $dotnetExePath = Join-Path -Path $LocalDotnetDirPath -ChildPath $dotnetFile
        }
    }
    
    if (Test-Path $dotnetExePath) {
        $installedVersion = & $dotnetExePath --version
        if ($Version -eq 'latest') {
            # TODO: This could query the version if you have the latest
            return $false
        } else {
            return $installedVersion -ge $Version
        }
    }
    return $false
}