using namespace System.Runtime.InteropServices

function Install-Dotnet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Channel,
        
        [Parameter(Mandatory=$true)]
        [string]
        $Version,
        
        [Parameter(Mandatory=$true)]
        [string]
        $InstallDir
    )

    $IsWindowsEnv = [RuntimeInformation]::IsOSPlatform([OSPlatform]::Windows)

    $obtainUrl = "https://raw.githubusercontent.com/dotnet/cli/master/scripts/obtain"

    try {
        Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
        $installScript = if ($IsWindowsEnv) { "dotnet-install.ps1" } else { "dotnet-install.sh" }
        Invoke-WebRequest -Uri $obtainUrl/$installScript -OutFile $installScript

        if ($IsWindowsEnv) {
            & .\$installScript -Channel $Channel -Version $Version -InstallDir $InstallDir
        } else {
            bash ./$installScript -c $Channel -v $Version --install-dir $InstallDir
        }
    }
    finally {
        Remove-Item $installScript -Force -ErrorAction SilentlyContinue
    }
}