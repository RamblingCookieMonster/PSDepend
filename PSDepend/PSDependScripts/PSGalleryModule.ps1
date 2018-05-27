<#
    .SYNOPSIS
        Installs a module from a PowerShell repository like the PowerShell Gallery.

    .DESCRIPTION
        Installs a module from a PowerShell repository like the PowerShell Gallery.

        Relevant Dependency metadata:
            Name: The name for this module
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
            Target: Used as 'Scope' for Install-Module.  If this is a path, we use Save-Module with this path.  Defaults to 'AllUsers'
            AddToPath: If target is used as a path, prepend that path to ENV:PSModulePath

        If you don't have the Nuget package provider, we install it for you

    .PARAMETER Repository
        PSRepository to download from.  Defaults to PSGallery

    .PARAMETER SkipPublisherCheck
        Bypass the catalog signing check.  Defaults to $false

    .PARAMETER AllowClobber
        Allow installation of modules that clobber existing commands.  Defaults to $True

    .PARAMETER Import
        If specified, import the module in the global scope

        Deprecated.  Moving to PSDependAction

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency
        Import: Import the dependency

    .EXAMPLE
        @{
            BuildHelpers = 'latest'
            PSDeploy = ''
            InvokeBuild = '3.2.1'
        }

        # From the PSGallery repository (PowerShellGallery.com)...
            # Install the latest BuildHelpers and PSDeploy ('latest' and '' both evaluate to latest)
            # Install version 3.2.1

    .EXAMPLE
        @{
            BuildHelpers = @{
                Target = 'C:\Build'
            }
        }

        # Install the latest BuildHelpers module from PSGallery to C:\Build (i.e. C:\Build\BuildHelpers will be the module folder)
        # No version is specified - we assume latest in this case.

    .EXAMPLE
        @{
            BuildHelpers = @{
                Parameters @{
                    Repository = 'PSPrivateGallery'
                    SkipPublisherCheck = $true
                }
            }
        }

        # Install the latest BuildHelpers module from a custom gallery* that you registered, and bypass the catalog signing check
        # No version is specified - we assume latest in this case.

        # * Perhaps you use this https://github.com/PowerShell/PSPrivateGallery, or Artifactory, ProGet, etc.
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [string]$Repository = 'PSGallery', # From Parameters...

    [bool]$SkipPublisherCheck, # From Parameters...

    [bool]$AllowClobber = $True,

    [switch]$Import,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install')
)

# Extract data from Dependency
    $DependencyName = $Dependency.DependencyName
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

    if('AllUsers', 'CurrentUser' -notcontains $Scope)
    {
        $command = 'save'
    }
    else
    {
        $command = 'install'
    }

if(-not (Get-PackageProvider -Name Nuget))
{
    # Grab nuget bits.
    $null = Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
}

Write-Verbose -Message "Getting dependency [$name] from PowerShell repository [$Repository]"
$params = @{
    Name = $Name
    Repository = $Repository
    SkipPublisherCheck = $SkipPublisherCheck
    AllowClobber = $AllowClobber
    Verbose = $VerbosePreference
    Force = $True
}

if( $Version -and $Version -ne 'latest')
{
    $Params.add('RequiredVersion',$Version)
}

# This code works for both install and save scenarios.
if($command -eq 'Save')
{
    $ModuleName =  Join-Path $Scope $Name
    $Params.Remove('AllowClobber')
    $Params.Remove('SkipPublisherCheck')
}
elseif ($Command -eq 'Install')
{
    $ModuleName = $Name
}

# Only use "SkipPublisherCheck" (and other) parameter if "Install-Module" supports it
$availableParameters = (Get-Command "Install-Module").Parameters
$tempParams = $Params.Clone()
foreach($thisParameter in $Params.Keys)
{
    if(-Not ($availableParameters.ContainsKey($thisParameter)))
    {
        Write-Verbose -Message "Removing parameter [$thisParameter] from [Install-Module] as it is not available"
        $tempParams.Remove($thisParameter)
    }
}
$Params = $tempParams.Clone()

Add-ToPsModulePathIfRequired -Dependency $Dependency -Action $PSDependAction

$Existing = $null
$Existing = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue

if($Existing)
{
    Write-Verbose "Found existing module [$Name]"
    # Thanks to Brandon Padgett!
    $ExistingVersion = $Existing | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    $GetGalleryVersion = { Find-Module -Name $Name -Repository $Repository | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum }

    # Version string, and equal to current
    if( $Version -and $Version -ne 'latest' -and $Version -eq $ExistingVersion)
    {
        Write-Verbose "You have the requested version [$Version] of [$Name]"
        # Conditional import
        Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $ExistingVersion

        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }

    # latest, and we have latest
    if( $Version -and
        ($Version -eq 'latest' -or $Version -like '') -and
        ($GalleryVersion = (& $GetGalleryVersion)) -le $ExistingVersion
    )
    {
        Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and PSGallery version [$GalleryVersion]"
        # Conditional import
        Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $ExistingVersion

        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }
    Write-Verbose "Continuing to install [$Name]: Requested version [$version], existing version [$ExistingVersion]"
}

#No dependency found, return false if we're testing alone...
if( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
{
    return $False
}

if($PSDependAction -contains 'Install')
{
    if('AllUsers', 'CurrentUser' -contains $Scope)
    {
        Write-Verbose "Installing [$Name] with scope [$Scope]"
        Install-Module @params -Scope $Scope
    }
    else
    {
        Write-Verbose "Saving [$Name] with path [$Scope]"
        Write-Verbose "Creating directory path to [$Scope]"
        if(-not (Test-Path $Scope -ErrorAction SilentlyContinue))
        {
            $Null = New-Item -ItemType Directory -Path $Scope -Force -ErrorAction SilentlyContinue
        }
        Save-Module @params -Path $Scope
    }
}

# Conditional import
$importVs = $params['RequiredVersion']
Import-PSDependModule -Name $ModuleName -Action $PSDependAction -Version $importVs
