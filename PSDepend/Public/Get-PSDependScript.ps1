Function Get-PSDependScript {
    <#
    .SYNOPSIS
        Get dependency types and associated scripts

    .DESCRIPTION
        Get dependency types and associated scripts

        Checks PSDepend.yml,
        verifies dependency scripts exist,
        returns a hashtable of these.

    .PARAMETER Path
        Path to PSDepend.yml defining deployment types

        Defaults to PSDepend.yml in the module root

    .LINK
        about_PSDepend

    .LINK
        https://github.com/RamblingCookieMonster/PSDepend
    #>
    [cmdletbinding()]
    param(
        [validatescript({Test-Path $_ -PathType Leaf -ErrorAction Stop})]
        [string]$Path = $(Join-Path $ModulePath PSDepend.yml)
    )

    # Abstract out reading the yaml and verifying scripts exist
    $DependencyDefinitions = ConvertFrom-Yaml -Path $Path

    $DependHash = @{}
    foreach($DependencyType in $DependencyDefinitions.Keys)
    {
        #Determine the path to this script
        $Script =  $DependencyDefinitions.$DependencyType.Script
        if(Test-Path $Script -ErrorAction SilentlyContinue)
        {
            $ScriptPath = $Script
        }
        else
        {
            # account for missing ps1
            $ScriptPath = Join-Path $ModulePath "PSDependScripts\$($Script -replace ".ps1$").ps1"
        }

        if(test-path $ScriptPath)
        {
            $DependHash.$DependencyType = $ScriptPath
        }
        else
        {
            Write-Error "Could not find path '$ScriptPath' for dependency $DependencyType. Origin: $($DependencyDefinitions.$DependencyType.Script)"
        }
    }

    $DependHash
}