Function Invoke-PSDepend {
    <#
    .SYNOPSIS
        Invoke PSDepend

    .DESCRIPTION
        Invoke PSDepend

        Searches for .depend.psd1 files in the current and nested paths, and invokes their dependencies

        See Get-Help about_PSDepend for more information.

    .PARAMETER Path
        Path to a specific depend.psd1 file, or to a folder that we recursively search for *.depend.psd1 files

        Defaults to the current path

    .PARAMETER Recurse
        If path is a folder, whether to recursively search for *.depend.psd1 files under that folder

        Defaults to $True

    .PARAMETER Tags
        Only invoke dependencies that are tagged with all of the specified Tags (-and, not -or)

    .PARAMETER PSDependTypePath
        Specify a psdepend.yml file that maps DependencyTypes to their scripts.

        This defaults to the psdepend.yml in the PSDepend module folder

    .PARAMETER Force
        Force dependency, skipping prompts and confirmation

    .EXAMPLE
        Invoke-PSDepend

    .LINK
        about_PSDepend

    .LINK
        https://github.com/RamblingCookieMonster/PSDepend
    #>
    [cmdletbinding( SupportsShouldProcess = $True,
                    ConfirmImpact='High' )]
    Param(
        [validatescript({Test-Path -Path $_ -ErrorAction Stop})]
        [parameter( ValueFromPipeline = $True,
                    ValueFromPipelineByPropertyName = $True)]
        [string[]]$Path = '.',

        # Add later. Pass on to Invoke-PSDeployment.
        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDepend.yml),

        [string[]]$Tags,

        [bool]$Recurse = $True,

        [switch]$Force
    )
    Begin
    {
        # This script reads a deployment YML, deploys files or folders as defined
        Write-Verbose "Running Invoke-PSDepend with ParameterSetName '$($PSCmdlet.ParameterSetName)' and params: $($PSBoundParameters | Out-String)"

        $RejectAll = $false
        $ConfirmAll = $false

        $DependencyFiles = New-Object System.Collections.ArrayList
    }
    Process
    {
        foreach( $PathItem in $Path )
        {
            # Create a map for dependencies
            Try
            {
                # Debating whether to make this a terminating error.
                # Stop all deployments because one is misconfigured?
                # I'm going with Copy-Item precedent.
                # Not terminating, so try catch is superfluous. Feel free to make this strict...
                [void]$DependencyFiles.AddRange( @( Resolve-DependScripts -Path $PathItem -Recurse $Recurse ) )
                if ($DependencyFiles.count -gt 0)
                {
                    Write-Verbose "Working with $($DependencyFiles.Count) dependency files:`n$($DependencyFiles | Out-String)"
                }
                else
                {
                    Write-Warning "No *.depend.ps1 files found under '$PathItem'"
                }
            }
            Catch
            {
                Throw "Error retrieving dependencies from '$PathItem':`n$_"
            }
        }

        # Parse
        $GetPSDependParams = @{Path = $DependencyFiles}
        if($PSBoundParameters.ContainsKey('Tags'))
        {
            $GetPSDependParams.Add('Tags',$Tags)
        }

        $De = Get-PSDeploymentScript

        # Handle Dependencies
        $ToDeploy = Get-PSDeployment @GetPSDeployParams
        foreach($Deployment in $ToDeploy)
        {
            $Type = $Deployment.DeploymentType

            $TheseParams = @{'DeploymentParameters' = @{}}
            if($Deployment.DeploymentOptions.Keys.Count -gt 0 -and -not ($Type -eq 'Task' -and $Type.Source -is [scriptblock]))
            {
                # Shoehorn Deployment Options into DeploymentParameters
                # Needed if we support both yml and ps1 definitions...

                # First, get the script, parse out parameters, restrict splatting to valid params
                $DeploymentScript = $DeploymentScripts.$Type
                $ValidParameters = Get-ParameterName -Command $DeploymentScript

                $FilteredOptions = @{}
                foreach($key in $Deployment.DeploymentOptions.Keys)
                {
                    if($ValidParameters -contains $key)
                    {
                        $FilteredOptions.Add($key, $Deployment.DeploymentOptions.$key)
                    }
                    else
                    {
                        Write-Warning "WithOption '$Key' is not a valid parameter for '$Type'"
                    }
                }
                $hash = @{$Type = $FilteredOptions}
                $TheseParams.DeploymentParameters = $hash
            }

            $Deploy = $True #anti pattern! Best I could come up with to handle both prescript fail and dependencies

            if($Deployment.Dependencies.ScriptBlock)
            {
                Write-Verbose "Checking dependency:`n$($Deployment.Dependencies.ScriptBlock)"
                if( -not $( . $Deployment.Dependencies.ScriptBlock ) )
                {
                    $Deploy = $False
                    Write-Warning "Skipping Deployment '$($Deployment.DeploymentName)', did not pass scriptblock`n$($Deployment.Dependencies.ScriptBlock | Out-String)"
                }
            }

            if($Deployment.PreScript.Count -gt 0)
            {
                $ExistingEA = $ErrorActionPreference
                foreach($script in $Deployment.Prescript)
                {
                    if($Script.SkipOnError)
                    {
                        Try
                        {
                            Write-Verbose "Invoking pre script: $($Script.ScriptBlock)"
                            $ErrorActionPreference = 'Stop'
                            . $Script.ScriptBlock
                        }
                        Catch
                        {
                            $Deploy = $False
                            Write-Error $_
                        }
                    }
                    else
                    {
                        . $Script.ScriptBlock
                    }
                }
                $ErrorActionPreference = $ExistingEA
            }

            if($Deploy)
            {
                $Deployment | Invoke-PSDeployment @TheseParams @InvokePSDeploymentParams
            }

            if($Deployment.PostScript.Count -gt 0)
            {
                foreach($script in $Deployment.PostScript)
                {
                    Write-Verbose "Invoking post script: $($Script.ScriptBlock)"
                    . $Script.ScriptBlock
                }
            }
        }
    }
}