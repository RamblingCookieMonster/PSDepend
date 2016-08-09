<#
    .SYNOPSIS
        Installs a module from a PowerShell repository like the PowerShell Gallery using nuget.exe

    .DESCRIPTION
        Installs a module from a PowerShell repository like the PowerShell Gallery using nuget.exe

        Note that this will remove any existing module from 

        Relevant Dependency metadata:
            Name: The name for this module
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
            Source: Source Uri for Nuget.  Defaults to https://www.powershellgallery.com/api/v2/
            Target: Required path to save this module.  No Default
                Example: To install PSDeploy to C:\temp\PSDeploy, I would specify C:\temp
            AddToPath: Add the Target to ENV:PSModulePath

    .PARAMETER Force
        If specified and Target is specified, create folders if needed

    .PARAMETER Import
        If specified, import the module in the global scope
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [switch]$Force,

    [switch]$ExcludeVersion,

    [switch]$Import
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

    $Source = $Dependency.Source
    if(-not $Dependency.Source)
    {
        $Source = 'https://www.powershellgallery.com/api/v2/'
    }

    # We use target as a proxy for Scope
    if(-not $Dependency.Target)
    {
        Write-Error "PSGalleryNuget requires a Dependency Target. Skipping [$DependencyName]"
        return
    }

if(-not (Get-Command Nuget.exe -ErrorAction SilentlyContinue))
{
    Write-Error "PSGalleryNuget requires Nuget.exe.  Ensure this is in your path, or explicitly specified in $ModuleRoot\PSDepend.NugetPath.  Skipping [$DependencyName]"
}

Write-Verbose -Message "Getting dependency [$name] from Nuget source [$Source]"

$params = @($Name, '-ExcludeVersion', '-Source', $Source, '-OutputDirectory', "$Target")

if( $Version -and $Version -ne 'latest')
{
    $Params.add('-Version',$Version)
}

# This code works for both install and save scenarios.
$ModulePath =  Join-Path $Target $Name

## BREAK

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

$ImportParam = @{}
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
        Write-Verbose "Setting PSModulePath to`n$($env:PSModulePath, $Scope -join ';' | Out-String)"
        $env:PSModulePath = $env:PSModulePath, $Scope -join ';'
    }
}

if($Import)
{
    Write-Verbose "Importing [$ModuleName]"
    Import-Module $ModuleName -Scope Global -Force 
}