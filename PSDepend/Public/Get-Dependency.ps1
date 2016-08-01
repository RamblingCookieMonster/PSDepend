function Get-Dependency {
    <#
    .SYNOPSIS
        Read a dependency file

    .DESCRIPTION
        Read a dependency file

    .PARAMETER Path
        Path to project root or dependency file.

        If a folder is specified, we search for and process *.depend.psd1 files.    
    #>
    [cmdletbinding()]
    param(
        [string[]]$Path = $PWD.Path,
        [string[]]$Tags,
        [switch]$Recurse
    )

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
        $DependencyFiles = $DependencyFiles | Select -Unique

        $DependencyMap = foreach($DependencyFile in $DependencyFiles)
        {

            # Read the file
            $Base = Split-Path $DependencyFile -Parent
            $File = Split-Path $DependencyFile -Leaf
            $Dependencies = Import-LocalizedData -BaseDirectory $Base -FileName $File

            foreach($Dependency in $Dependencies.keys)
            {
                $DependencyHash = $Dependencies.$Dependency

                #Parse simple key=name, value=version format
                if($DependencyHash -isnot [hashtable])
                {
                    [pscustomobject]@{
                        DependencyFile = $DependencyFile
                        DependencyName = $Dependency
                        Name = $Dependency
                        Version = $DependencyHash
                        Source = 'PSGalleryModule'
                        Parameters = $null
                        Target = $null
                        AddToPath = $null
                        Tags = $null
                        Dependencies = $null
                        PreScripts = $null
                        PostScripts = $null
                        Raw = $null         
                    }
                }
                else
                {
                    # Parse dependency hash format
                    # A few defaults...
                    if(-not $DependencyHash.ContainsKey('Name'))
                    {
                        $DependencyHash.add('Name', $Dependency)
                    }
                    if(-not $DependencyHash.ContainsKey('Source'))
                    {
                        $DependencyHash.add('Source', 'PSGallery')
                    }

                    [pscustomobject]@{
                        DependencyFile = $DependencyFile
                        DependencyName = $Dependency
                        Name = $DependencyHash.Name
                        Version = $DependencyHash.Version
                        Source = $DependencyHash.Source
                        Parameters = $DependencyHash.Parameters
                        Target = $DependencyHash.Target
                        AddToPath = $DependencyHash.AddToPath
                        Tags = $DependencyHash.Tags
                        Dependencies = $DependencyHash.Dependencies
                        PreScripts = $DependencyHash.PreScripts
                        PostScripts = $DependencyHash.PostScripts
                        Raw = $DependencyHash
                    }
                }
            }
        }

        If($PSBoundParameters.ContainsKey('Tags'))
        {
            $DependencyMap = Get-TaggedDeployment -Deployment $DependencyMap -Tags $Tags
            if(-not $DependencyMap)
            {
                Write-Warning "No dependencies found with tags '$tags'"
                return
            }
        }

        Sort-PSDependency -Dependencies $DependencyMap
    }
}