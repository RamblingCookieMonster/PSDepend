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

    .PARAMETER Force
        If specified and Target is specified, create folders if needed

    .PARAMETER Import
        If specified, import the module in the global scope

        Deprecated.  Moving to PSDependAction

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency
        Import: Import the dependency
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [string]$Repository = 'PSGallery', # From Parameters...

    [switch]$Force,

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

# Validate that $target has been setup as a valid PowerShell repository
$validRepo = Get-PSRepository -Name $Repository -Verbose:$false -ErrorAction SilentlyContinue
if (-not $validRepo) {
    Write-Error "[$Repository] has not been setup as a valid PowerShell repository."
    return
}

$params = @{
    Name = $Name
    Repository = $Repository
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
}
elseif ($Command -eq 'Install')
{
    $ModuleName = $Name
}
$Existing = $null
$Existing = Get-Module -ListAvailable -Name $ModuleName -ErrorAction SilentlyContinue

if($Existing)
{
    Write-Verbose "Found existing module [$Name]"
    # Thanks to Brandon Padgett!
    $ExistingVersion = $Existing | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    $GalleryVersion = Find-Module -Name $Name -Repository PSGallery | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum
    
    # Version string, and equal to current
    if( $Version -and $Version -ne 'latest' -and $Version -eq $ExistingVersion)
    {
        Write-Verbose "You have the requested version [$Version] of [$Name]"
        # Conditional import
        Import-PSDependModule -Name $ModuleName -Action $PSDependAction

        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }
    
    # latest, and we have latest
    if( $Version -and
        ($Version -eq 'latest' -or $Version -like '') -and
        $GalleryVersion -le $ExistingVersion
    )
    {
        Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and PSGallery version [$GalleryVersion]"
        
        # Conditional import
        Import-PSDependModule -Name $ModuleName -Action $PSDependAction

        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }

    Write-Verbose "Continuing to install [$Name]: Requested version [$version], existing version [$ExistingVersion], PSGallery version [$GalleryVersion]"
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
    elseif((Test-Path $Scope -PathType Container) -or $Force)
    {
        Write-Verbose "Saving [$Name] with path [$Scope]"
        if($Force)
        {
            Write-Verbose "Force creating directory path to [$Scope]"
            $Null = New-Item -ItemType Directory -Path $Scope -Force -ErrorAction SilentlyContinue
        }
        Save-Module @params -Path $Scope

        if($Dependency.AddToPath)
        {
            Write-Verbose "Setting PSModulePath to`n$($Scope, $env:PSModulePath -join ';' | Out-String)"
            Add-ToItemCollection -Reference Env:\PSModulePath -Item $Scope
        }
    }
}

# Conditional import
Import-PSDependModule -Name $ModuleName -Action $PSDependAction