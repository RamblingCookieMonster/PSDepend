<#
    .SYNOPSIS
        EXPERIMENTAL: Installs a package using the PackageManagement module

    .DESCRIPTION
        EXPERIMENTAL: Installs a package using the PackageManagement module

        Relevant Dependency metadata:
            Name: The name for this Package
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
            Target: Used as 'Scope' for Install-Package. Defaults to 'AllUsers', also accepts 'CurrentUser'
            Source: Package source to use (Get-PackageSource, Register-PackageSource)
            Parameters: Every parameter you specify is splatted against Install-Package

        If you don't have the Nuget package provider, we install it for you

    .PARAMETER Repository
        PSRepository to download from.  Defaults to PSGallery

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install')
)

# Extract data from Dependency
    $DependencyName = $Dependency.DependencyName
    $Source = $Dependency.Source
    $Name = $Dependency.Name
    if(-not $Name)
    {
        $Name = $DependencyName
    }

    $Version = $Dependency.Version
    if(-not $Version)
    {
        $Version = 'latest'
    }

    # We use target as a proxy for Scope
    if(-not $Dependency.Target)
    {
        $Scope = 'AllUsers'
    }
    else
    {
        $Scope = $Dependency.Target
    }

$PackageSources = @( Get-PackageSource )
if($PackageSources.ProviderName -notcontains $Source)
{
    Write-Error "PackageSource [$Source] is not valid.  Valid sources:`n$($PackageSources.ProviderName | Out-String)"
    return
}
Write-Verbose -Message "Getting dependency [$name] from Package source [$Source]"
$ThisProvider = $PackageSources | Where {$_.Name -eq $Source} | Select -ExpandProperty ProviderName

$GetParam = @{
    Name = $Name
    ProviderName = $ThisProvider
    ErrorAction = 'SilentlyContinue'
}
$InstallParam = @{
    Name = $Name
    Source = $Source
    Force = $True
    Scope = $Scope
}
if($Version -notlike 'latest')
{
    $GetParam.add('RequiredVersion', $Version)
    $InstallParam.add('RequiredVersion', $Version)
}
if($Dependency.Parameters.Keys.Count -gt 0)
{
    foreach($Key in $Dependency.Parameters.Keys)
    {
        if(-not $InstallParam.ContainsKey($Key))
        {
            $InstallParam.add($Key, $Dependency.Parameters.$Key)
        }
        else
        {
            $InstallParam.$Key = $Dependency.Parameters.$Key
        }
    }
}

$Existing = $null
Write-Verbose "Running Get-Package with $($GetParam | Out-String)"
$Existing = Get-Package @GetParam

if($Existing)
{
    Write-Verbose "Found existing package [$Name]"
    # Thanks to Brandon Padgett!
    $ExistingVersion = $Existing | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    $SourceVersion = Find-Package -Name $Name -Source $Source | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    
    # Version string, and equal to current
    if( $Version -and $Version -ne 'latest' -and $Version -eq $ExistingVersion)
    {
        Write-Verbose "You have the requested version [$Version] of [$Name]"
        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }
    
    # latest, and we have latest
    if( $Version -and
        ($Version -eq 'latest' -or $Version -like '') -and
        $SourceVersion -le $ExistingVersion
    )
    {
        Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and package source version [$SourceVersion]"
        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }

    Write-Verbose "Continuing to install [$Name]: Requested version [$version], existing version [$ExistingVersion], package source version [$SourceVersion]"
}

#No dependency found, return false if we're testing alone...
if( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
{
    return $False
}

if($PSDependAction -contains 'Install')
{
    Write-Verbose "Installing [$Name] with scope [$Scope]"
    Install-Module @InstallParam
}

