[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install')
)

$Version = $Dependency.Version
if($Dependency.Target) { 
    $InstallDir = $Dependency.Target
}
$Channel = if($Dependency.DependencyName) { $Dependency.DependencyName } else { "LTS" }

if ($PSDependAction -contains 'Test') {
    return Test-Dotnet -Version $Version -InstallDir $InstallDir
}

if ($PSDependAction -contains 'Install') {
    if (!(Test-Dotnet -Version $Version -InstallDir $InstallDir)) {
        if (!$InstallDir) {
            $IsWindowsEnv = [RuntimeInformation]::IsOSPlatform([OSPlatform]::Windows)
            $InstallDir = if ($IsWindowsEnv) { "$env:LocalAppData\Microsoft\dotnet" } else { "$env:HOME/.dotnet" }
        }
        Install-Dotnet -Channel $Channel -Version $Version -InstallDir $InstallDir
    }
}

if ($PSDependAction -contains 'Import') {
    if ($InstallDir -and (Test-Dotnet -Version $Version -InstallDir $InstallDir)) {
        $dotnetFile = if ($IsWindowsEnv) { "dotnet.exe" } else { "dotnet" }
        $env:PATH = (Join-Path $InstallDir $dotnetFile) + [IO.Path]::PathSeparator + $env:PATH
    } else {
        $dotnetInPath = Get-Command 'dotnet' -ErrorAction SilentlyContinue
        if(!$dotnetInPath) {
            throw ".NET SDK cannot be located. Try installing using PSDepend."
        }
    }
}
