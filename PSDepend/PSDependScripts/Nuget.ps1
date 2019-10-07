<#
    .SYNOPSIS
        Installs a package from a Nuget repository like Nuget.org using nuget.exe

    .DESCRIPTION
        Installs a package from a Nuget repository like Nuget.org using nuget.exe

        Relevant Dependency metadata:
            Name: The name of the package
            Version: Used to identify existing installs meeting this criteria.  Defaults to 'latest'
            Source: Source Uri for Nuget.  Defaults to https://www.nuget.org/api/v2/
            Target: Required path to save this module.  No Default
                Example: To install PSDeploy to C:\temp\PSDeploy, I would specify C:\temp

    .PARAMETER Force
        If specified and Target already exists, remove existing item before saving

    .PARAMETER PSDependAction
        Test, or Install the package.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency

    .EXAMPLE

        @{
            'Newtonsoft.Json' = @{
                DependencyType = 'Nuget'
                Target = 'C:\Temp'
                Version = '12.0.2'
            }
        }

        # Install Newtonsoft.Json via Nuget.org, to C:\temp, at version 12.0.2

    .EXAMPLE

        @{
            'MyCompany.Models' = @{
                DependencyType = 'Nuget'
                Source = 'https://nuget.int.feed/'
                Target = 'C:\Temp'
            }
        }

        # Install the latest version of MyCompany.Models on an internal nuget feed, to C:\temp

    .EXAMPLE

        @{
            PSDependOptions = @{
                DependencyType = 'Nuget'
                Target = ".\Staging"
            }
            'BouncyCastle' = 'latest'
            'Google.Apis' = 'latest'
            'Google.Apis.Admin.DataTransfer.datatransfer_v1' = 'latest'
            'Google.Apis.Admin.Directory.directory_v1' = 'latest'
            'Google.Apis.Admin.Reports.reports_v1' = 'latest'
            'Google.Apis.Auth' = 'latest'
            'Google.Apis.Auth.PlatformServices' = 'latest'
            'Google.Apis.Calendar.v3' = 'latest'
            'Google.Apis.Classroom.v1' = 'latest'
            'Google.Apis.Core' = 'latest'
            'Google.Apis.Docs.v1' = 'latest'
            'Google.Apis.Drive.v3' = 'latest'
            'Google.Apis.DriveActivity.v2' = 'latest'
            'Google.Apis.Gmail.v1' = 'latest'
            'Google.Apis.Groupssettings.v1' = 'latest'
            'Google.Apis.HangoutsChat.v1' = 'latest'
            'Google.Apis.Licensing.v1' = 'latest'
            'Google.Apis.Oauth2.v2' = 'latest'
            'Google.Apis.PeopleService.v1' = 'latest'
            'Google.Apis.PlatformServices' = 'latest'
            'Google.Apis.Script.v1' = 'latest'
            'Google.Apis.Sheets.v4' = 'latest'
            'Google.Apis.Slides.v1' = 'latest'
            'Google.Apis.Tasks.v1' = 'latest'
            'Google.Apis.Urlshortener.v1' = 'latest'
            'MimeKit' = 'latest'
            'Newtonsoft.Json' = 'latest'
        }

        # Installs the list of Nuget packages from Nuget.org using the Global PSDependOptions to limit repetition. Packages will be downloaded to the Staging directory in the current working directory.

#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [switch]$Force,

    [ValidateSet('Test', 'Install')]
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

    $Source = $Dependency.Source
    if(-not $Dependency.Source)
    {
        $Source = 'https://www.nuget.org/api/v2/'
    }

    # We use target as a proxy for Scope
    $Target = $Dependency.Target
    if(-not $Dependency.Target)
    {
        Write-Error "Nuget requires a Dependency Target. Skipping [$DependencyName]"
        return
	}

	$Credential = $Dependency.Credential

if(-not (Get-Command Nuget -ErrorAction SilentlyContinue))
{
    Write-Error "Nuget requires Nuget.exe.  Ensure this is in your path, or explicitly specified in $ModuleRoot\PSDepend.Config's NugetPath.  Skipping [$DependencyName]"
}

Write-Verbose -Message "Getting dependency [$name] from Nuget source [$Source]"

# This code works for both install and save scenarios.
$PackagePath =  Join-Path $Target $Name

if(Test-Path $PackagePath)
{
    if($null -eq (Get-ChildItem $PackagePath -Filter "$($Name).dll" -Recurse))
    {
        # For now, skip if we don't find a DLL matching the expected name
        Write-Error "Could not existing DLL for dependency [$Name] in package path [$PackagePath]"
        return
    }

    Write-Verbose "Found existing package [$Name]"

    # Thanks to Brandon Padgett!
    $dllPath = (Get-ChildItem $PackagePath -Filter "$($Name).dll" -Recurse | Select-Object -First 1).FullName
    $ExistingVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($dllPath).FileVersion
    $GetGalleryVersion = { (Find-NugetPackage -Name $Name -PackageSourceUrl $Source -Credential $Credential -IsLatest).Version }

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
        ($GalleryVersion = [System.Version](& $GetGalleryVersion)) -le [System.Version]$ExistingVersion
    )
    {
        Write-Verbose "You have the latest version of [$Name], with installed version [$ExistingVersion] and Source version [$GalleryVersion]"
        if($PSDependAction -contains 'Test')
        {
            return $True
        }
        return $null
    }

    Write-Verbose "Removing existing [$PackagePath]`nContinuing to install [$Name]: Requested version [$version], existing version [$ExistingVersion]"
    if($PSDependAction -contains 'Install')
    {
        if($Force)
        {
            Remove-Item $PackagePath -Force -Recurse
        }
        else
        {
            Write-Verbose "Use -Force to remove existing [$PackagePath]`nSkipping install of [$Name]: Requested version [$version], existing version [$ExistingVersion]"
            if( $PSDependAction -contains 'Test')
            {
                return $false
            }
            return $null
        }
    }
}

#No dependency found, return false if we're testing alone...
if( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
{
    return $False
}

if($PSDependAction -contains 'Install')
{
    $TargetExists = Test-Path $Target -PathType Container

    Write-Verbose "Saving [$Name] with path [$Target]"
    $NugetParams = '-Source', $Source, '-ExcludeVersion', '-NonInteractive', '-OutputDirectory', $Target
    if(-not $TargetExists)
    {
        Write-Verbose "Creating directory path to [$Target]"
        $Null = New-Item -ItemType Directory -Path $Target -Force -ErrorAction SilentlyContinue
    }
    if($Version -and $Version -notlike 'latest')
    {
        $NugetParams += '-version', $Version
    }
    $NugetParams = 'install', $Name + $NugetParams

	Invoke-ExternalCommand nuget -Arguments $NugetParams
}
