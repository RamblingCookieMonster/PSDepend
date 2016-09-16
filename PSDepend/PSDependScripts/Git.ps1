<#
    .SYNOPSIS
        Clone a git repository

    .DESCRIPTION
        Clone a git repository

        Note: We require git.exe in your path

        Relevant Dependency metadata:
            DependencyName (Key): Git URL
                You can override this with the 'Name'.
                If you specify only an Account/Repository, we assume GitHub is the source
            Name: Optional override for the Git URL, same rules as DependencyName (key)
            Version: Used with git checkout.  Specify a branch name, commit hash, or tags/<tag name>, for example.  Defaults to master
            Target: Path to clone this repository.  e.g C:\Temp would result in C:\Temp\RepoName.  Defaults to nothing (current path/repo name)
            AddToPath: Prepend the Target to ENV:PATH and ENV:PSModulePath

    .PARAMETER Force
        If specified and target does not exist, create directory tree up to the target folder

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place (Note: Currently only checks if path exists)
        Install: Install the dependency
        Import: Import the dependency 'Target'.  Override with ImportPath

    .PARAMETER ImportPath
        If specified with PSDependAction Import, we import this path, instead of Target, the default

    .EXAMPLE
        @{
            'buildhelpers' = @{
                Name = 'https://github.com/RamblingCookieMonster/BuildHelpers.git'
                Version = 'd32a9495c39046c851ceccfb7b1a85b17d5be051'
                Target = 'C:\git'
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
          # Both are cloned to the current path (e.g. .\<repo name>)
          # This syntax assumes GitHub as a source. The right hand side is the version (branch, commit, tags/<tag name>, etc.
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [switch]$Force,

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install'),

    [string]$ImportPath
)

# Extract data from Dependency
$DependencyName = $Dependency.DependencyName
$Name = $Dependency.Name
if(-not $Name)
{
    $Name = $DependencyName
}

#Name is in account/repo format, default to GitHub as source
#This likely needs work, and will need to change if GitHub changes valid characters for usernames
if($Name -match "^[a-zA-Z0-9]+/[a-zA-Z0-9_-]+$")
{
    $Name = "https://github.com/$Name.git"
}
$GitName = $Name.trimend('/').split('/')[-1] -replace "\.git$", ''
$Target = $Dependency.Target
if(-not $Target)
{
    $Target = $PWD.Path
}
$RepoPath = Join-Path $Target $GitName
$GottaInstall = $True

if(-not (Test-Path $Target) -and $PSDependAction -contains 'Install')
{
    Write-Verbose "Creating folder [$Target] for git dependency [$Name]"
    $null = mkdir $Target -Force
}

if(-not (Test-Path $RepoPath))
{
    # Nothing found, return test output
    if( $PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
    {
        return $False
    }
}
else # Target exists
{
    $GottaTest = $True
}

if(-not (Get-Command git.exe -ErrorAction SilentlyContinue))
{
    Write-Error "Git dependency type requires git.exe.  Ensure this is in your path, or explicitly specified in $ModuleRoot\PSDepend.Config's GitPath.  Skipping [$DependencyName]"
}

$Version = $Dependency.Version
if(-not $Version)
{
    $Version = 'master'
}

if($GottaTest)
{
    Push-Location
    Set-Location $RepoPath
    $Branch = Invoke-ExternalCommand git -Arguments (echo rev-parse --abbrev-ref HEAD) -Passthru
    $Commit = Invoke-ExternalCommand git -Arguments (echo rev-parse HEAD) -Passthru
    Pop-Location
    if($Version -eq $Branch -or $Version -eq $Commit)
    {
        Write-Verbose "[$RepoPath] exists and is already at version [$Version]"
        if($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
        {
            return $true
        }
        $GottaInstall = $False
    }
    elseif($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
    {
        Write-Verbose "[$RepoPath] exists and is at branch [$Branch], commit [$Commit].`nWe don't currently support moving to the requested version [$Version]"
        return $false
    }
    else
    {
        Write-Verbose "[$RepoPath] exists and is at branch [$Branch], commit [$Commit].`nWe don't currently support moving to the requested version [$Version]"
        $GottaInstall = $False
    }
}

if($PSDependAction -notcontains 'Install')
{
    return
}

if($GottaInstall)
{
    Push-Location
    Set-Location $Target
    Write-Verbose -Message "Cloning dependency [$Name] with git from [$($Target)]"
    Invoke-ExternalCommand git 'clone', $Name

    #TODO: Should we do a fetch, once existing repo is found?
    Set-Location $RepoPath
    Write-Verbose -Message "Checking out [$Version] of [$Name] from [$RepoPath]"
    Invoke-ExternalCommand git 'checkout', $Version
    Pop-Location
}

if($Dependency.AddToPath)
{
    Write-Verbose "Setting PSModulePath to`n$($Target, $env:PSModulePath -join ';' | Out-String)"
    Add-ToItemCollection -Reference Env:\PSModulePath -Item $Target
    
    Write-Verbose "Setting PATH to`n$($RepoPath, $env:PATH -join ';' | Out-String)"
    Add-ToItemCollection -Reference Env:\Path -Item $Target
}

$ToImport = $Target
if($ImportPath)
{
    $ToImport = $ImportPath
}
Import-PSDependModule $ToImport