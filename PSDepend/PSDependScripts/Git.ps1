<#
    .SYNOPSIS
        EXPERIMENTAL: Clone a git repository

    .DESCRIPTION
        EXPERIMENTAL: Clone a git repository

        Note: We require git.exe in your path

        Relevant Dependency metadata:
            DependencyName (Key): Git URL
                You can override this with the 'Name'.
                If you specify only an Account/Repository, we assume GitHub is the source
            Name: Optional override for the Git URL, same rules as DependencyName (key)
            Version: Used with git checkout.  Specify a branch name, commit hash, or tags/<tag name>, for example.  Defaults to master
            Target: Path to clone this repository.  Defaults to nothing (current path/repo name)
            AddToPath: Add the Target to ENV:PATH and ENV:PSModulePath

    .PARAMETER Force
        If specified and target does not exist, create directory tree up to the target folder

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
          # Both are cloned to the current path (e.g. .\<repo name>)
          # This syntax assumes GitHub as a source. The right hand side is the version (branch, commit, tags/<tag name>, etc.
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

    #Name is in account/repo format, default to GitHub as source
    #This likely needs work, and will need to change if GitHub changes valid characters for usernames
    if($Name -match "[a-zA-Z0-9]+/[a-zA-Z0-9_-]+")
    {
        $Name = "https://github.com/$Name.git"
    }
    $GitName = $Name.split('/')[-1] -replace "\.git[/]?$", ''

    $Target = $Dependency.Target
    if($Target)
    {
        $RepoPath = $Target
        if(-not (Test-Path $Target))
        {
            mkdir $Target -Force
        }
    }
    else
    {
        $RepoPath = Join-Path $PWD.Path $GitName
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

Write-Verbose -Message "Cloning dependency [$Name] with git"
$CloneParams = @('clone', $Name)
if($Target)
{
    $CloneParams += $Target
}

#TODO: Add logic to test for existing repo
git @CloneParams
Push-Location
Set-Location $RepoPath

#TODO: Should we do a fetch, once existing repo is found?
Write-Verbose -Message "Checking out [$Version] of [$Name]"
$CheckoutParams = @('checkout', $Version)
git @CheckoutParams
Pop-Location

if($Dependency.AddToPath)
{
    Write-Verbose "Setting PSModulePath to`n$($env:PSModulePath, $RepoPath -join ';' | Out-String)"
    $env:PSModulePath = $env:PSModulePath, $RepoPath -join ';'
    
    Write-Verbose "Setting PATH to`n$($env:PATH, $RepoPath -join ';' | Out-String)"
    $env:PATH = $env:PATH, $RepoPath -join ';'
}
