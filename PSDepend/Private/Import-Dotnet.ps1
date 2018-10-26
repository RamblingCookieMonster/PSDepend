# Adds the .NET Core SDK to the PATH if it is a valid version.
function Import-Dotnet {
    [CmdletBinding()]
    param(       
        [Parameter(Mandatory=$true)]
        [string]
        $Version,
        
        [Parameter()]
        [string]
        $InstallDir
    )

    # The 'global' install location is different per platform
    $IsWindowsEnv = !$PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT"
    $globalDotnetSdkLocation = if ($IsWindowsEnv) { "$env:LocalAppData\Microsoft\dotnet" } else { "$env:HOME/.dotnet" }

    $dotnetInPath = Get-Command 'dotnet' -ErrorAction SilentlyContinue
    $dotnetInPathIsGood = $dotnetInPath -and (Test-Dotnet -Version $Version -InstallDir $dotnetInPath.Source)

    # Check if the one in the PATH is good enough
    if ($dotnetInPathIsGood) {
        return
    }

    # If the InstallDir was specified and the .NET Core SDK exists in it, add it to the path
    if ($InstallDir) {
        if (Test-Dotnet -Version $Version -InstallDir $InstallDir) {
            $env:PATH = "$InstallDir$([IO.Path]::PathSeparator)$env:PATH"
        } else {
            throw ".NET SDK cannot be located or it's not new enough. Try installing using PSDepend."
        }
    } else {
        if (Test-Dotnet -Version $Version -InstallDir $globalDotnetSdkLocation) {
            $env:PATH = "$globalDotnetSdkLocation$([IO.Path]::PathSeparator)$env:PATH"
        } else {
            throw ".NET SDK cannot be located or it's not new enough. Try installing using PSDepend."
        }
    }
}
