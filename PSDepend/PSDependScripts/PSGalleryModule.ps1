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
			Credential: The username and password used to authenticate against the private repository

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

    .PARAMETER Clean
        Deletes existing versions of the module before installing/saving desired version

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

    [AllowNull()]
    [string]$Repository = 'PSGallery', # From Parameters...

    [bool]$SkipPublisherCheck, # From Parameters...

    [bool]$AllowClobber = $True,

    [switch]$Import,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install'),

    [switch]$Clean
)

# Extract data from Dependency
$Name = $Dependency.Name
if(-not $Name)
{
    $Name = $Dependency.DependencyName
}

$findModuleSplat = @{
    Name = $Name
}

$moduleSplat = @{
    Name               = $Name
    Verbose            = $VerbosePreference
    Force              = $True
}

# We use target as a proxy for Scope
$install = $True
if($Dependency.Target -and 'AllUsers', 'CurrentUser' -notcontains $Dependency.Target)
{
    $install = $false
    $moduleFullname =  Join-Path -Path $Dependency.Target -ChildPath $Name
}
else
{
    if ($Dependency.Target)
    {
        $scope = $Dependency.Target
    }
    else
    {
        $scope = 'AllUsers'
    }

    $moduleFullname = $Name
    $moduleSplat['AllowClobber'] = $AllowClobber
    $moduleSplat['SkipPublisherCheck'] = $SkipPublisherCheck
    $moduleSplat['Scope'] = $scope
}

if(-not (Get-PackageProvider -Name Nuget))
{
    # Grab nuget bits.
    $null = Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
}

Write-Verbose -Message "Getting dependency [$name] from PowerShell repository [$Repository]"

# Validate that $target has been setup as a valid PowerShell repository,
#   but allow to rely on all PS repos registered.
if($Repository)
{
    if (-not (Get-PSRepository -Name $Repository -Verbose:$false -ErrorAction SilentlyContinue))
    {
        Write-Error "[$Repository] has not been setup as a valid PowerShell repository."
        return
    }
}

if ($Repository)
{
    $findModuleSplat.Add('Repository',$Repository)
    $moduleSplat.Add('Repository',$Repository)
}

if ($Dependency.Credential)
{
	$findModuleSplat.Add('Credential', $Dependency.Credential)
	$moduleSplat.add('Credential', $Dependency.Credential)
}

if ($Dependency.Version)
{
    $Version = $Dependency.Version
    $moduleSplat.add('RequiredVersion',$Version)
}
else
{
    $Version = (Find-Module @findModuleSplat).Version.ToString()
}

Write-Verbose "Targetting module '$Name' Version: $Version"

# Only use "SkipPublisherCheck" (and other) parameter if "Install-Module" supports it
$availableParameters = (Get-Command "Install-Module").Parameters
$tempmoduleSplat = $moduleSplat.Clone()
foreach($thisParameter in $moduleSplat.Keys)
{
    if(-Not ($availableParameters.ContainsKey($thisParameter)))
    {
        Write-Verbose -Message "Removing parameter [$thisParameter] from [Install-Module] as it is not available"
        $tempmoduleSplat.Remove($thisParameter)
    }
}

$moduleSplat = $tempmoduleSplat.Clone()
Add-ToPsModulePathIfRequired -Dependency $Dependency -Action $PSDependAction

$existingModules = $null
$existingModules = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue
 
if ($PSDependAction -contains 'Install')
{
    # If Clean is set to $true, cleanup any existing versions of the module
    if ($PSDependAction -notcontains 'Test' -and $Clean -and $existingModules)
    {
        Write-Verbose "Parameter 'Clean' set to 'true', removing existing versions..."
        foreach ($existingModule in $existingModules)
        {
            $existingVersion = $existingModule.Version.ToString()
            Write-Verbose "Found existing module: '$Name' Version: $existingVersion"
            $differentModulePath = (Get-Item -Path $existingModule.ModuleBase).Parent.FullName -ne $moduleFullname
            if (($existingVersion -ne $Version -and $Target.Location -and $differentModulePath) -or $existingVersion -ne $Version)
            {
                # Remove module from session just in case
                Write-Verbose "Removing existing module: '$($existingModule.Name)' Version: $existingVersion"
                Remove-Module -Name $existingModule.Name -Force -ErrorAction SilentlyContinue -Verbose:$false
                
                # Pause to give the module a chance to be fully removed from session
                Start-Sleep -Seconds 1
                Remove-Item -Path $existingModule.ModuleBase -Force -Recurse         
            }
        }
    }
    
    if (-not $install)
    {
        if (-not (Test-Path -Path $moduleFullname -ErrorAction SilentlyContinue))
        {
            Write-Verbose "Creating directory path to '$moduleFullname'"
            $null = New-Item -ItemType Directory -Path $moduleFullname -Force -ErrorAction SilentlyContinue
        }

        $modulePath = Join-Path -Path $moduleFullname -ChildPath $Version
        if(-not (Test-Path -Path $modulePath -ErrorAction SilentlyContinue))
        {
            Write-Verbose "Saving '$Name' with path '$moduleFullname'"
            Save-Module @moduleSplat -Path (Split-Path -Path $moduleFullname -Parent)
        }
    }
    else
    {
        Write-Verbose "Installing [$Name] with scope [$Scope]"
        Install-Module @moduleSplat
    }
}

if ($PSDependAction -contains 'Import')
{
    Write-Verbose "You have the requested version [$Version] of [$Name]"
    # Conditional import
    Import-PSDependModule -Name $moduleFullname -Action $PSDependAction -Version $Version

    if($PSDependAction -contains 'Test')
    {
        return $True
    }
}

if ($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
{
    return ($existingModules | Foreach-Object {$_.Version.ToString()}) -contains $Version
}
