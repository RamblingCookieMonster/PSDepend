Function Install-Dependency {
    <#
    .SYNOPSIS
        Install a dependency

    .DESCRIPTION
        Install a dependency

        Takes output from Get-Dependency

          * Runs dependency scripts depending on each dependencies type.
          * If a dependency is not found, we continue processing other dependencies.

        See Get-Help about_PSDepend for more information.

    .PARAMETER Dependency
        Dependency object from Get-Dependency.

    .PARAMETER PSDependTypePath
        Specify a PSDepend.yml file that maps DependencyTypes to their scripts.

        This defaults to the PSDepend.yml in the PSDepend module folder

    .PARAMETER Tags
        Only invoke dependencies that are tagged with all of the specified Tags (-and, not -or)

    .PARAMETER Force
        Force installation, skipping prompts and confirmation
    #>
    [cmdletbinding( DefaultParameterSetName = 'Map',
                    SupportsShouldProcess = $True,
                    ConfirmImpact='High' )]
    Param(
        [parameter( ValueFromPipeline = $True,
                    ParameterSetName='Map',
                    Mandatory = $True)]
        [psobject]$Dependency,

        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [parameter( ParameterSetName='File',
                    Mandatory = $True)]
        [string[]]$Path,

        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDepend.yml),

        [string[]]$Tags,

        [switch]$Force
    )
    Begin
    {
        # This script reads a dependency YML, installs dependencies as defined
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
            #Get definitions, and dependencies in this particular yml
            $DependencyDefs = Get-PSDependScript
            $TheseDependencyTypes = @( $Dependency.Source | Sort -Unique )

            #Build up hash, we call each dependencytype script for applicable dependencies
            $ToInstall = @{}
            foreach($DependencyType in $TheseDependencyTypes)
            {
                $DependencyScript = $DependencyDefs.$DependencyType
                if(-not $DependencyScript)
                {
                    Write-Error "DependencyType $DependencyType is not defined in PSDepend.yml"
                    continue
                }
                $TheseDependencies = @( $Dependency | Where-Object {$_.Source -eq $DependencyType})

                #Parameters for dependency types.  Only accept valid params...
                if($Dependency.Parameters.keys.count -gt 0)
                {
                    #Define params for the script
                    #Each dependency type can have a hashtable to splat.
                    $ValidParameters = Get-ParameterName -Command $DependencyScript

                    $FilteredOptions = @{}
                    foreach($key in $Dependency.Parameters.keys)
                    {
                        if($ValidParameters -contains $key)
                        {
                            $FilteredOptions.Add($key, $Dependency.Parameters.$key)
                        }
                        else
                        {
                            Write-Warning "Parameter [$Key] with value [$($Dependency.Parameters.$Key)] is not a valid parameter for [$DependencyType], ignoring"
                        }
                    }
                    $splat = $FilteredOptions
                }
                else
                {
                    $splat = @{}
                }
                #Define params for the script
                $splat.add('Dependency', $TheseDependencies)


                # PITA, but tasks can run two ways, each different than typical dependency scripts
                if($DependencyType -eq 'Task')
                {
                    foreach($Dependency in $TheseDependencies)
                    {
                        foreach($TaskScript in $Dependency.Target)
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
                }
                else
                {
                    . $DependencyScript @splat
                }
            }
        }
    }
}