function Get-Dependency {
    <#
    .SYNOPSIS
        Read a dependency psd1 file

    .DESCRIPTION
        Read a dependency psd1 file

        The resulting object contains these properties
            DependencyFile : Path to psd1 file this dependency is defined in
            DependencyName : Unique dependency name (the key in the psd1 file).  We reserve PSDependOptions for global options.
            DependencyType : Type of dependency.  See Get-PSDependType
            Name           : Name for the dependency
            Version        : Version for the dependency
            Parameters     : Hash table of parameters to pass to dependency script
            Source         : Source for the dependency
            Target         : Target for the dependency
            AddToPath      : If specified and dependency type supports it, add dependency to path (e.g. a module is added to PSModulePath)
            Tags           : One or more tags to categorize or filter dependencies
            DependsOn      : Dependency that must be installed before this
            PreScripts     : One or more paths to PowerShell scripts to run before the dependency
            PostScripts    : One or more paths to PowerShell scripts to run after the dependency
            PSDependOptions: Hash table of global PSDepend options
            Raw            : Raw output for this dependency from the PSD1. May include data outside of standard items above.

        These are parsed from dependency PSD1 files as follows:

        Simple syntax:
            @{
                DependencyName = 'Version'
            }

            With the simple syntax:
               * The DependencyName (key) is used as the Name
               * If no DependencyType is specified, we parse the DependencyName to pick a default:
                 * We default to GitHub if the DependencyName has a single / (e.g. aaa/bbb)
                 * We default to git if the DependencyName has more than one / (e.g. https://gitlab.fqdn/org/some.git)
                 * We default to PSGalleryModule in all other cases
               * The Version (value) is a string, and is used as the Version
               * Other properties are set to $null

        Advanced syntax:
            @{
                DependencyName = @{
                    DependencyType = 'TypeOfDependency'.  # See Get-PSDependType
                    Name = 'NameForThisDependency'
                    Version = '0.1.0'
                    Parameters = @{ Example = 'Value' }  # Optional parameters for the dependency script.
                    Source = 'Some source' # Usually optional
                    Target = 'Some target' # Usually optional
                    AddToPath = $True # Whether to add new dependency to path, if dependency type supports it.
                    Tags = 'prod', 'local' # One or more tags to categorize or filter dependencies
                    DependsOn = 'Some_Other_DependencyName' # DependencyName that must run before this
                    PreScripts = 'C:\script.ps1' # Script(s) to run before this dependency
                    PostScripts = 'C:\script2.ps1' # Script(s) to run after this dependency
                }
            }

        We use the same default DeploymentTypes for this advanced syntax

        Global options:
           @{
               PSDependOptions = @{
                   Target = 'C:\temp'
               }
               # Supported for:
               #    Parameters
               #    Source
               #    Target
               #    AddToPath
               #    Tags
               #    DependsOn
               #    PreScripts
               #    PostScripts

               # Dependencies use these values as a default, unless you specify them explicitly for a dependency
           }

        Note that you can mix these syntax together in the same psd1.

    .PARAMETER Path
        Path to project root or dependency file.

        If a folder is specified, we search for and process *.depend.psd1 and requirements.psd1 files.

    .PARAMETER Tags
        Limit results to one or more tags defined in the Dependencies

    .PARAMETER Recurse
        If specified and path is a container, search for *.depend.psd1 and requirements.psd1 files recursively under $Path

    .LINK
        about_PSDepend

    .LINK
        about_PSDepend_Definitions

    .LINK
        Get-PSDependScript

    .LINK
        Get-PSDependType

    .LINK
        Install-Dependency

    .LINK
        Invoke-PSDepend

    .LINK
        https://github.com/RamblingCookieMonster/PSDepend
    #>
    [cmdletbinding()]
    param(
        [string[]]$Path = $PWD.Path,
        [string[]]$Tags,
        [switch]$Recurse
    )

    # Helper to pick from global psdependoptions, or return a default
    function Get-GlobalOption {
        param(
            $Options = $PSDependOptions,
            $Name,
            $Prefer,
            $Default = $null
        )
        # Check for preferred value, otherwise try to get value from key, otherwise use default....
        $Output = $Default
        if($Prefer)
        {
            $Output = $Prefer
        }
        else
        {
            try
            {
                $Output = $Options[$Name]
            }
            catch
            {
                $Output = $Default
            }
        }

        # Inject variables
        if( $Name -eq 'Target' -or $Name -eq 'Source')
        {
            $Output = Inject-Variable $Output
        }
        $Output
    }

    function Inject-Variable {
        [cmdletbinding()]
        param( $Value )
        $Output = $Value
        switch($Value)
        {
            {$_ -match '^\.$|^\.\\|^\./'}{
                $Output = $Output -replace '^\.', $PWD.Path
            }

            {$_ -Match '\$PWD'} {
                $Output = $Output -replace '\$PWD', $PWD.Path
            }

            {$_ -Match '\$ENV:ProgramData'} {
                $Output = $Output -replace '\$ENV:ProgramData', $ENV:ProgramData
            }
            {$_ -Match '\$ENV:USERPROFILE'} {
                $Output = $Output -replace '\$ENV:USERPROFILE', $ENV:USERPROFILE
            }
            {$_ -Match '\$ENV:APPDATA'} {
                $Output = $Output -replace '\$ENV:APPDATA', $ENV:APPDATA
            }
            {$_ -Match '\$ENV:TEMP'} {
                $Output = $Output -replace '\$ENV:TEMP', $ENV:TEMP
            }

            {$_ -Match '\$DependencyFolder|\$DependencyPath'} {
                $DependencyFolder = Split-Path $DependencyFile -Parent
                $Output = $Output -replace '\$DependencyFolder|\$DependencyPath', $DependencyFolder
            }
        }
        $Output
    }

    foreach($DependencyPath in $Path)
    {
        #Resolve relative paths... Thanks Oisin! http://stackoverflow.com/a/3040982/3067642
        $DependencyPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DependencyPath)

        if(Test-Path $DependencyPath -PathType Container)
        {
            $DependencyFiles = @( Resolve-DependScripts -Path $DependencyPath -Recurse $Recurse )
        }
        else
        {
            $DependencyFiles = @( $DependencyPath )
        }
        $DependencyFiles = $DependencyFiles | Select-Object -Unique

        $DependencyMap = foreach($DependencyFile in $DependencyFiles)
        {
            # Read the file
            $Base = Split-Path $DependencyFile -Parent
            $File = Split-Path $DependencyFile -Leaf
            $Dependencies = Import-LocalizedData -BaseDirectory $Base -FileName $File

            # Global settings....
            $PSDependOptions = $null
            if($Dependencies.Containskey('PSDependOptions'))
            {
                $PSDependOptions = $Dependencies.PSDependOptions
                $Dependencies.Remove('PSDependOptions')
            }

            foreach($Dependency in $Dependencies.keys)
            {
                $DependencyHash = $Dependencies.$Dependency
                $DependencyType = Get-GlobalOption -Name DependencyType

                #Parse simple key=name, value=version format
                # It doesn't look like a git repo, and simple syntax: PSGalleryModule
                if( $DependencyHash -is [string] -and
                    $Dependency -notmatch '/' -and
                    -not $DependencyType -or
                    $DependencyType -eq 'PSGalleryModule')
                {
                    [pscustomobject]@{
                        PSTypeName = 'PSDepend.Dependency'
                        DependencyFile = $DependencyFile
                        DependencyName = $Dependency
                        DependencyType = 'PSGalleryModule'
                        Name = $Dependency
                        Version = $DependencyHash
                        Parameters = Get-GlobalOption -Name Parameters
                        Source = Get-GlobalOption -Name Source
                        Target = Get-GlobalOption -Name Target
                        AddToPath = Get-GlobalOption -Name AddToPath
                        Tags = Get-GlobalOption -Name Tags
                        DependsOn = Get-GlobalOption -Name DependsOn
                        PreScripts =  Get-GlobalOption -Name PreScripts
                        PostScripts =  Get-GlobalOption -Name PostScripts
                        PSDependOptions = $PSDependOptions
                        Raw = $null
                    }
                }
                # It looks like a git repo, simple syntax, and not a full URI
                elseif($DependencyHash -is [string] -and
                       $Dependency -match '/' -and
                       $Dependency.split('/').count -eq 2 -and
                       -not $DependencyType -or
                       $DependencyType -eq 'GitHub')
                {
                    [pscustomobject]@{
                        PSTypeName = 'PSDepend.Dependency'
                        DependencyFile = $DependencyFile
                        DependencyName = $Dependency
                        DependencyType = 'GitHub'
                        Name = $Dependency
                        Version = $DependencyHash
                        Parameters = Get-GlobalOption -Name Parameters
                        Source = Get-GlobalOption -Name Source
                        Target = Get-GlobalOption -Name Target
                        AddToPath = Get-GlobalOption -Name AddToPath
                        Tags = Get-GlobalOption -Name Tags
                        DependsOn = Get-GlobalOption -Name DependsOn
                        PreScripts = Get-GlobalOption -Name PreScripts
                        PostScripts = Get-GlobalOption -Name PostScripts
                        PSDependOptions = $PSDependOptions
                        Raw = $null
                    }
                }
                # It looks like a git repo, and simple syntax: Git
                elseif($DependencyHash -is [string] -and
                       $Dependency -match '/' -and
                       -not $DependencyType -or
                       $DependencyType -eq 'Git' )
                {
                    [pscustomobject]@{
                        PSTypeName = 'PSDepend.Dependency'
                        DependencyFile = $DependencyFile
                        DependencyName = $Dependency
                        DependencyType = 'Git'
                        Name = $Dependency
                        Version = $DependencyHash
                        Parameters = Get-GlobalOption -Name Parameters
                        Source = Get-GlobalOption -Name Source
                        Target = Get-GlobalOption -Name Target
                        AddToPath = Get-GlobalOption -Name AddToPath
                        Tags = Get-GlobalOption -Name Tags
                        DependsOn = Get-GlobalOption -Name DependsOn
                        PreScripts = Get-GlobalOption -Name PreScripts
                        PostScripts = Get-GlobalOption -Name PostScripts
                        PSDependOptions = $PSDependOptions
                        Raw = $null
                    }
                }
                else
                {
                    # Parse dependency hash format
                    # Default type is module, unless it's in a git-style format
                    if(-not $DependencyHash.DependencyType)
                    {
                        # Is it a global option?
                        if($DependencyType) {}
                        # GitHub first
                        elseif(
                            # Ugly right? Watch out for split called on hashtable...
                            ($Dependency -match '/' -and -not $Dependency.Name -and
                                ($Dependency -is [string] -and $Dependency.split('/').count -eq 2)
                            ) -or
                            ($DependencyHash.Name -match '/' -and
                                ($DependencyHash -is [string] -and $DependencyHash.split('/').count -eq 2)
                            )
                        )
                        {
                            $DependencyType = 'GitHub'
                        }
                        # Now git...
                        elseif(
                            ($Dependency -match '/' -and -not $Dependency.Name) -or
                            $DependencyHash.Name -match '/'
                        )
                        {
                            $DependencyType = 'Git'
                        }
                        else # finally, psgallerymodule
                        {
                            $DependencyType = 'PSGalleryModule'
                        }
                    }
                    else
                    {
                        $DependencyType = $DependencyHash.DependencyType
                    }

                    [pscustomobject]@{
                        PSTypeName = 'PSDepend.Dependency'
                        DependencyFile = $DependencyFile
                        DependencyName = $Dependency
                        DependencyType = $DependencyType
                        Name = $DependencyHash.Name
                        Version = $DependencyHash.Version
                        Parameters = Get-GlobalOption -Name Parameters -Prefer $DependencyHash.Parameters
                        Source = Get-GlobalOption -Name Source -Prefer $DependencyHash.Source
                        Target = Get-GlobalOption -Name Target -Prefer $DependencyHash.Target
                        AddToPath = Get-GlobalOption -Name AddToPath -Prefer $DependencyHash.AddToPath
                        Tags = Get-GlobalOption -Name Tags -Prefer $DependencyHash.Tags
                        DependsOn = Get-GlobalOption -Name DependsOn -Prefer $DependencyHash.DependsOn
                        PreScripts = Get-GlobalOption -Name PreScripts -Prefer $DependencyHash.PreScripts
                        PostScripts = Get-GlobalOption -Name PostScripts -Prefer $DependencyHash.PostScripts
                        PSDependOptions = $PSDependOptions
                        Raw = $DependencyHash
                    }

                    Clear-Variable DependencyType
                }
            }
        }

        If($PSBoundParameters.ContainsKey('Tags'))
        {
            $DependencyMap = Get-TaggedDependency -Dependency $DependencyMap -Tags $Tags
            if(-not $DependencyMap)
            {
                Write-Warning "No dependencies found with tags '$tags'"
                return
            }
        }
        Sort-PSDependency -Dependencies $DependencyMap
    }
}
