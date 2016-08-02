Function Invoke-PSDepend {
    <#
    .SYNOPSIS
        Invoke PSDepend

    .DESCRIPTION
        Invoke PSDepend

        Searches for and runs *.depend.psd1 files in the current and nested paths

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
        Specify a PSDependMap.psd1 file that maps DependencyTypes to their scripts.

        This defaults to the PSDependMap.psd1 in the PSDepend module folder

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

        [validatescript({Test-Path -Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$PSDependTypePath = $(Join-Path $ModuleRoot PSDependMap.psd1),

        [string[]]$Tags,

        [bool]$Recurse = $True,

        [switch]$Force
    )
    Begin
    {
        # This script reads a depend.psd1, deploys files or folders as defined
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
            [void]$DependencyFiles.AddRange( @( Resolve-DependScripts -Path $PathItem -Recurse $Recurse ) )
            if ($DependencyFiles.count -gt 0)
            {
                Write-Verbose "Working with [$($DependencyFiles.Count)] dependency files from [$PathItem]:`n$($DependencyFiles | Out-String)"
            }
            else
            {
                Write-Warning "No *.depend.ps1 files found under [$PathItem]"
            }
        }

        # Parse
        $GetPSDependParams = @{Path = $DependencyFiles}
        if($PSBoundParameters.ContainsKey('Tags'))
        {
            $GetPSDependParams.Add('Tags',$Tags)
        }

        $DependencyScripts = Get-PSDependScript

        # Handle Dependencies
        $ToInstall = Get-Dependency @GetPSDependParams

        #TODO: Add ShouldProcess here.  Having it in Install-Dependency is bad.
        foreach($Dependency in $ToInstall)
        {
            $Type = $Dependency.DependencyType
            $Install = $True #anti pattern! Best I could come up with to handle both prescript fail and dependencies

            if($Deployment.PreScripts.Count -gt 0)
            {
                $ExistingEA = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
                foreach($script in $Dependency.Prescripts)
                {
                    Try
                    {
                        Write-Verbose "Invoking pre script: [$Script]"
                        . $Script
                    }
                    Catch
                    {
                        $Install = $False
                        "Skipping installation due to failed pre script: [$Script]"
                        Write-Error $_
                    }
                }
                $ErrorActionPreference = $ExistingEA
            }

            if($Install)
            {
                Install-Dependency -Dependency $Dependency
            }

            if($Dependency.PostScript.Count -gt 0)
            {
                foreach($script in $Deployment.PostScript)
                {
                    Write-Verbose "Invoking post script: $($Script)"
                    . $Script
                }
            }
        }
    }
}



