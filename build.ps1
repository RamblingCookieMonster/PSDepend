[CmdletBinding()]
param (
    [parameter(Position = 0)]
    [ValidateSet('Default','Init','Test','Build','Deploy')]
    $Task = 'Default'
)

# Grab nuget bits, install modules, set build variables, start build.
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

Install-Module Psake, PSDeploy, BuildHelpers -force -AllowClobber -Scope CurrentUser
Install-Module Pester -RequiredVersion 4.10.1 -Force -AllowClobber -SkipPublisherCheck -Scope CurrentUser
Import-Module Psake, BuildHelpers

Set-BuildEnvironment -ErrorAction SilentlyContinue

Invoke-psake -buildFile $ENV:BHProjectPath\psake.ps1 -taskList $Task -nologo
exit ( [int]( -not $psake.build_success ) )
