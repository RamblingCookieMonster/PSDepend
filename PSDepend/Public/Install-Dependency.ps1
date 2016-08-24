Function Install-Dependency {
    <#
    .SYNOPSIS
        Install a specific dependency

    .DESCRIPTION
        Install a specific dependency.  Typically you would use Invoke-PSDepend rather than this.

        Takes output from Get-Dependency

          * Runs dependency scripts depending on each dependencies type.
          * If a dependency is not found, we continue processing other dependencies.

        See Get-Help about_PSDepend for more information.

    .PARAMETER Dependency
        Dependency object from Get-Dependency.

    .PARAMETER PSDependTypePath
        Specify a PSDependMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PSDependMap.psd1 in the PSDepend module folder

    .PARAMETER Tags
        Only invoke dependencies that are tagged with all of the specified Tags (-and, not -or)

    .PARAMETER Force
        Force installation, skipping prompts and confirmation

    .EXAMPLE
        Get-Dependency -Path C:\requirements.psd1 | Install-Dependency

        Get dependencies from C:\requirements.psd1 and resolve them

    .LINK
        about_PSDepend

    .LINK
        about_PSDepend_Definitions

    .LINK
        Get-Dependency

    .LINK
        Get-PSDependType

    .LINK
        Invoke-PSDepend

    .LINK
        https://github.com/RamblingCookieMonster/PSDepend
    #>
    [cmdletbinding( DefaultParameterSetName = 'Map',
                    SupportsShouldProcess = $True,
                    ConfirmImpact='High' )]
    Param(
        [parameter( ValueFromPipeline = $True,
                    ParameterSetName='Map',
                    Mandatory = $True)]
        [PSTypeName('PSDepend.Dependency')]
        [psobject[]]$Dependency,

        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1),

        [string[]]$Tags,

        [switch]$Force
    )
    Begin
    {
        # This script reads a depend.psd1, installs dependencies as defined
        Write-Verbose "Running Install-Dependency with ParameterSetName '$($PSCmdlet.ParameterSetName)' and params: $($PSBoundParameters | Out-String)"
    }
    Process
    {
        Write-Verbose "Dependencies:`n$($Dependency | Out-String)"

        if( ($Force -and -not $WhatIf) -or
            $PSCmdlet.ShouldProcess( "Processed the dependency '$($Dependency.DependencyName -join ", ")'",
                                    "Process the dependency '$($Dependency.DependencyName -join ", ")'?",
                                    "Processing dependency" ))
        {
            #Get definitions, and dependencies in this particular psd1
            $DependencyDefs = Get-PSDependScript
            $TheseDependencyTypes = @( $Dependency.DependencyType | Sort -Unique )

            #Build up hash, we call each dependencytype script for applicable dependencies
            $ToInstall = @{}
            foreach($DependencyType in $TheseDependencyTypes)
            {
                $DependencyScript = $DependencyDefs.$DependencyType
                if(-not $DependencyScript)
                {
                    Write-Error "DependencyType $DependencyType is not defined in PSDependMap.psd1"
                    continue
                }
                $TheseDependencies = @( $Dependency | Where-Object {$_.DependencyType -eq $DependencyType})

                foreach($ThisDependency in $TheseDependencies)
                {
                    #Parameters for dependency types.  Only accept valid params...
                    if($ThisDependency.Parameters.keys.count -gt 0)
                    {
                        #Define params for the script
                        #Each dependency type can have a hashtable to splat.
                        $ValidParameters = ( Get-Parameter -Command $DependencyScript ).Name

                        $FilteredOptions = @{}
                        foreach($key in $ThisDependency.Parameters.keys)
                        {
                            if($ValidParameters -contains $key)
                            {
                                $FilteredOptions.Add($key, $ThisDependency.Parameters.$key)
                            }
                            else
                            {
                                Write-Warning "Parameter [$Key] with value [$($ThisDependency.Parameters.$Key)] is not a valid parameter for [$DependencyType], ignoring"
                            }
                        }
                        $splat = $FilteredOptions
                    }
                    else
                    {
                        $splat = @{}
                    }
                    #Define params for the script
                    $splat.add('Dependency', $ThisDependency)

                    # PITA, but tasks can run two ways, each different than typical dependency scripts
                    if($DependencyType -eq 'Task')
                    {
                        foreach($TaskScript in $ThisDependency.Target)
                        {
                            if( Test-Path $TaskScript -PathType Leaf)
                            {
                                . $TaskScript @splat
                            }
                            else
                            {
                                Write-Error "Could not process task [$TaskScript].`nAre connectivity, privileges, and other needs met to access it?"
                            }
                        }
                    }
                    else
                    {
                        . $DependencyScript @splat
                    }
                }
            }
        }
    }
}



