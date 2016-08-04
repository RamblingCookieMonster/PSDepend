<#
    .SYNOPSIS
        Installs a module from a PowerShell repository like the PowerShell Gallery.

    .DESCRIPTION
        Installs a module from a PowerShell repository like the PowerShell Gallery.

        Relevant Dependency metadata:
            Name: The name for this module
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
            Target: Used as 'Scope' for Install-Module.  If this is a path, we use Save-Module with this path.  Defaults to 'AllUsers'

        If you don't have the Nuget package provider, we install it for you

    .PARAMETER Repository
        PSRepository to download from.  Defaults to PSGallery

    .PARAMETER Force
        If specified and Target is specified, create folders if needed
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [string]$Repository = 'PSGallery', # From Parameters...

    [switch]$Force
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
    if('AllUsers', 'CurrentUser' -notcontains $Scope -and (Test-Path $Scope -PathType Container))
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
$Existing = $null
if($command -eq 'Save')
{
    $Existing = Get-Module -ListAvailable -Name (Join-Path $Scope $Name)
}
elseif ($Command -eq 'Install')
{
    $Existing = Get-Module -ListAvailable -Name $Name
}
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
        return $null
    }
    
    # latest, and we have latest
    if( $Version -and
        ($Version -eq 'latest' -or $Version -like '') -and
        $GalleryVersion -le $ExistingVersion
    )
    {
        Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and PSGallery version [$GalleryVersion]"
        return $null
    }

    Write-Verbose "Continuing to install [$Name]: Requested version [$version], existing version [$ExistingVersion], PSGallery version [$GalleryVersion]"
}

if('AllUsers', 'CurrentUser' -contains $Scope)
{   
    Install-Module @params -Scope $Scope
}
elseif(Test-Path $Scope -PathType Container)
{
    if($Force)
    {
        $Null = New-Item -ItemType Directory -Path $Scope -Force
    }
    Save-Module @params -Path $Scope
}
