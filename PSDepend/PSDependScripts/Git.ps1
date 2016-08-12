<#
    .SYNOPSIS
        EXPERIMENTAL: Clone a git repository

    .DESCRIPTION
        EXPERIMENTAL: Clone a git repository

        Note: We require git.exe in your path

        Relevant Dependency metadata:
            DependencyName (Key): Git URL.
                You can override this with the 'Name'.
                If you specify only an Account/Repository, we assume GitHub is the source
            Name: Optional override for the Git URL, same rules as DependencyName (key)
            Version: Used with git checkout.  Specify a branch name, commit hash, or tags/<tag name>, for example.  Defaults to master
            Target: Path to clone this repository.  Defaults to current path.
            AddToPath: Add the Target to ENV:PATH and ENV:PSModulePath

    .PARAMETER Force
        If specified and Target is specified, create folders to Target if needed

    .EXAMPLE
        @{
            'buildhelpers' @{
                Name = 'https://github.com/RamblingCookieMonster/BuildHelpers.git'
                Version = 'd32a9495c39046c851ceccfb7b1a85b17d5be051'
                Target = C:\git
            }
        }

        # Full syntax
          # DependencyName (key) uses (unique) name 'buildhelpers'
          # Override DependencyName as URL the name https://github.com/RamblingCookieMonster/BuildHelpers.git
          # Specify a commit to checkout (version)
          # Clone in C:\git

    .EXAMPLE

        @{
            'ramblingcookiemonster/PSDeploy' = 'master'
            'ramblingcookiemonster/BuildHelpers' = 'd32a9495c39046c851ceccfb7b1a85b17d5be051'
        }

        # Simple syntax
          # First example shows cloning PSDeploy from ramblingcookiemonster's GitHub account
          # Second example shows clonging PSDeploy from ramblingcookiemonster's GitHub account and checking out a specific commit
          # Both are cloned to the current path
          # This syntax assumes GitHub as a source, the right hand side is the version (branch, commit, tags/<tag name>, etc.
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

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
        $Version = 'master'
    }

if(-not (Get-Command git.exe -ErrorAction SilentlyContinue))
{
    Write-Error "Git dependency type requires git.exe.  Ensure this is in your path, or explicitly specified in $ModuleRoot\PSDepend.Config's GitPath.  Skipping [$DependencyName]"
}

Write-Verbose -Message "Getting dependency [$DependencyName] from Nuget source [$Source]"

$CloneParams = @('clone', $Name)
if($Target)
{
    $CloneParams += $Target
}

if(Test-Path $ModulePath)
{
    $Manifest = Join-Path $ModulePath "$Name.psd1"
    if(-not (Test-Path $Manifest))
    {
        # For now, skip if we don't find a psd1
        Write-Error "Could not find manifest [$Manifest] for dependency [$DependencyName]"
        return
    }

    Write-Verbose "Found existing module [$DependencyName]"

    # Thanks to Brandon Padgett!
    $ManifestData = Import-LocalizedData -BaseDirectory $ModulePath -FileName "$Name.psd1"
    $ExistingVersion = $ManifestData.ModuleVersion
    $GalleryVersion = ( Find-NugetPackage -Name $Name -PackageSourceUrl $Source -IsLatest ).Version
    
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

    Write-Verbose "Removing existing [$ModulePath]`nContinuing to install [$Name]: Requested version [$version], existing version [$ExistingVersion], PSGallery version [$GalleryVersion]"
    Remove-Item $ModulePath -Force -Recurse 
}

if(($TargetExists = Test-Path $Target -PathType Container) -or $Force)
{
    Write-Verbose "Saving [$Name] with path [$Target]"
    $NugetParams = '-Source', $Source, '-ExcludeVersion', '-NonInteractive', '-OutputDirectory', $Target
    if($Force)
    {
        Write-Verbose "Force creating directory path to [$Target]"
        $Null = New-Item -ItemType Directory -Path $Target -Force -ErrorAction SilentlyContinue
    }
    if($Version -and $Version -notlike 'latest')
    {
        $NugetParams += '-version', $Version
    }
    nuget.exe install $Name @NugetParams

    if($Dependency.AddToPath)
    {
        Write-Verbose "Setting PSModulePath to`n$($env:PSModulePath, $Scope -join ';' | Out-String)"
        $env:PSModulePath = $env:PSModulePath, $Target -join ';'
    }
}
else
{
    Write-Error "Target [$Target] exists must be true, and is [$TargetExists]. Alternatively, specify -Force to create the Target"
}

if($Import)
{
    Write-Verbose "Importing [$ModulePath]"
    Import-Module $ModulePath -Scope Global -Force 
}