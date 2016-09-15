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
               * We default to Git as the DependencyType if we see a '/', otherwise we default to PSGalleryModule
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
            $Default = $Null
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

                #Parse simple key=name, value=version format
                # It doesn't look like a git repo, and simple syntax: PSGalleryModule
                if( $DependencyHash -is [string] -and $Dependency -notmatch '/')
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
                # It looks like a git repo, and simple syntax: Git
                elseif($DependencyHash -is [string] -and $Dependency -match '/')
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
                    if(-not $DependencyHash.ContainsKey('DependencyType'))
                    {
                        # Look for git format:
                        if(
                            ($Dependency -match '/' -and -not $Dependency.Name) -or
                            $DependencyHash.Name -match '/'
                        )
                        {
                            $DependencyHash.add('DependencyType', 'Git')
                        }
                        else
                        {
                            $DependencyHash.add('DependencyType', 'PSGalleryModule')
                        }
                    }

                    [pscustomobject]@{
                        PSTypeName = 'PSDepend.Dependency'
                        DependencyFile = $DependencyFile
                        DependencyName = $Dependency
                        DependencyType = $DependencyHash.DependencyType
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
