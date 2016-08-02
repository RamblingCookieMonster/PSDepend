<#
    .SYNOPSIS
        Support dependencies by handling simple tasks.

    .DESCRIPTION
        Support dependencies by handling simple tasks.

        Relevant Dependency metadata:
            Target: One or more scripts to run for this task
            Parameters: Parameters to call against the task scripts

    .PARAMETER Dependency
        Dependency to process

    .PARAMETER Target
        One or more Task scripts to process
#>
[cmdletbinding()]
param (
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]
    $Dependency
)

Write-Verbose "Executing $($Dependency.count) tasks"

foreach($Depend in $Dependency)
{
    foreach($Task in $Depend.Source)
    {
        if(Test-Path $Task -PathType Leaf)
        {
            $params = @{}
            if($Depend.Parameters)
            {
                $params += $Depend.Parameters
            }
            . $Task @params
        }
        else
        {
            Write-Warning "Could not find task file [$Task] from dependency [$($Depend.DependencyName)]"
        }
    }
}