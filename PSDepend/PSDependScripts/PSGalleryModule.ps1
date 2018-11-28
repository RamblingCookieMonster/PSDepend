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
            Configuration = '-gt 1.1.1 -and -lt 2.0'
        }

        # From the PSGallery repository (PowerShellGallery.com)...
            # Install the latest BuildHelpers and PSDeploy ('latest' and '' both evaluate to latest)
            # Install version 3.2.1
            # Install the Configuration module (or use one available locally) matching a version between 1.1.1. and less than 2.0

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
    [ValidateScript( {
            # Validate the Repository is setup for this user/machine
            $Repository = $_
            if($Repository)
            {
                $validRepo = Get-PSRepository -Name $Repository -Verbose:$false -ErrorAction SilentlyContinue
                if (-not $validRepo)
                {
                    Throw "[$Repository] has not been setup as a valid PowerShell repository."
                }
            }
        })]
    [string]$Repository = 'PSGallery', # From Parameters...

    [bool]$SkipPublisherCheck, # From Parameters...

    [bool]$AllowClobber = $True,

    [bool]$AllowPrerelease = $false,

    [switch]$Import,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install')
)

Begin
{
    # Extract and set defaults
    $DependencyName = $Dependency.DependencyName
    $Name = $Dependency.Name
    if(!$Name)
    {
        $Name = $DependencyName
    }

    if(!($Scope = $Dependency.Target))
    {
        $Scope = 'AllUsers'
    }

    # if the version -eq latest:
    #  Find the latest available on Repository
    if($null -eq $Dependency.Version -or $Dependency.Version -eq 'Latest')
    {
        $FindLatestModuleParams = @{Name = $Name}
        $FindModuleCmd = Get-Command Find-Module
        foreach($key in $PSBoundParameters.Keys)
        {
            if($FindModuleCmd.Parameters.ContainsKey($_) -and
                $null -ne (Get-Variable $_ -ValueOnly)
            )
            {
                $FindLatestModuleParams.Add($_,$PSBoundParameters[$_])
            }
        }
        Write-Debug "Finding latest version of module $Name"
        $LatestModule = Find-Module @FindLatestModuleParams -ErrorAction Stop
        $VersionFilter = Get-SemVerFilterFromString -Filter "-eq $($LatestModule.Version)"
    }
    else
    {
        try
        {
            # Try to validate whether it's a valid SemVer (if it's a Filter it'll throw)
            if(Get-SemVerFromString -VersionString $Dependency.Version)
            {
                # Create a Version Filter for Required Version
                $VersionFilter = Get-SemVerFilterFromString -Filter "-eq $($Dependency.Version)"
            }
        }
        catch
        {
            # Convert the String Filter to a Working Filter
            $VersionFilter = Get-SemVerFilterFromString -Filter $Dependency.Version
        }
    }

    if('AllUsers', 'CurrentUser' -notcontains $Scope)
    {
        $command = Get-Command Save-Module
        # The Scope is a Path (coming from Target), append the name to it
        # we'll search existing module (matching version) based on that path
        $ModuleName = Join-Path -Path $Scope -ChildPath $Name
        $Path = $Scope
    }
    else
    {
        $command = Get-Command Install-Module
        $ModuleName = $Name
    }
}

Process
{
    Write-Debug "Finding the latest module matching the version filter installed locally"
    try
    {
        $Exists = Get-Module -ListAvailable -All -Name $ModuleName -ErrorAction Stop |
            Sort-Object Version -Descending | Where-Object $VersionFilter | Select-Object -First 1
    }
    catch
    {
        Write-Debug "No Module found"
    }

    if($Exists)
    {
        Write-Debug "... a module $ModuleName matching '$Filter' has been found locally"
        $ModuleToActOn = $Exists
    }
    elseif($Dependency.Version -eq 'latest' -or $null -eq $Dependency.Version)
    {
        if ($PSDependAction -contains 'test' -and $PSDependAction.count -eq 1)
        {
            Write-Debug "The Test action could not find a matching module. Skipping Import/Install/Save."
            return $false
        }
        Write-Debug "Latest module $ModuleName Not found locally. Will $($PSDependAction -join '/') the latest from feed"
        $ModuleToActOn = $LatestModule
    }
    else
    {
        #  Find All versions from the Gallery that match the Version filter | selecting the 1st
        Write-Debug "Finding remote version of '$ModuleName' matching criteria '$Filter'"
        $FindModuleAllVersionsParams = @{Name = $Name; AllVersions = $true}
        $FindModuleCmd = Get-Command Find-Module
        foreach($key in $PSBoundParameters.Keys)
        {
            if($FindModuleCmd.Parameters.ContainsKey($_) -and
                $null -ne (Get-Variable $_ -ValueOnly)
            )
            {
                $FindModuleAllVersionsParams.Add($_,$PSBoundParameters[$_])
            }
        }

        $ModuleToActOn = Find-Module @FindModuleAllVersionsParams -ErrorAction Stop |
            Where-Object $VersionFilter | Select-Object -First 1
    }

    Switch($PSDependAction)
    {
        'test'
        {
            if($Exists)
            {
                Write-Debug "Test module returned FOUND LOCALLY"
                Write-Output $True
            }
            else
            {
                Write-Debug "Test module returned NOT FOUND"
                Write-Output $false
            }
        }
        'Install'
        {
            if($Exists)
            {
                Write-Debug "Module already present on the System"
                if($Dependency.AddToPath)
                {
                    $ParentPath = [io.DirectoryInfo](Split-path $Exists.ModuleBase -Parent)
                    if($ParentPath.BaseName -eq $Module.Name)
                    {
                        $ModulePath = $ParentPath.FullName
                    }
                    else
                    {
                        $ModulePath = (Split-Path $ParentPath -Parent).ToString()
                    }

                    Add-ToItemCollection -Reference Env:\PSModulePath -Item $ModulePath
                }
            }
            else
            {
                Write-Debug "The module is not locally installed. Calling $($Command.DisplayName)"
                $CmdParam = @{} #add Target if Save
                if($Command.Verb -eq 'Save')
                {
                    If(!(Test-Path $Path))
                    {
                        $null = New-Item -Path $Path -Force -ItemType Directory
                    }
                    $CmdParam.add('Path',$Path)
                }
                $ModuleToActOn | &$command @CmdParam
            }

            if($Dependency.AddToPath -and $Path -notin @('CurrentUser','AllUsers'))
            {
                Write-Debug "Ensuring '$Path' is in `$ENV:PSmodulePath"
                Add-ToItemCollection -Reference Env:\PSModulePath -Item (Get-Item $path -Force).FullName
            }
        }
        'import'
        {
            $ModuleToActOn | Import-Module -Force -Scope Global
            if($Dependency.AddToPath -and $Path -notin @('CurrentUser','AllUsers'))
            {
                #Add-ToItemCollection -Reference Env:\PSModulePath -Item (Get-Item $path -Force).FullName
            }
        }
    }
}
