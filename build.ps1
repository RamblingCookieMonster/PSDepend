# Grab nuget bits, install modules, set build variables, start build.
Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null

Install-Module Psake, PSDeploy, BuildHelpers -force
Install-Module Pester -RequiredVersion 3.4.2 -Force
Import-Module Psake, BuildHelpers

Set-BuildEnvironment

Invoke-psake .\psake.ps1
exit ( [int]( -not $psake.build_success ) )