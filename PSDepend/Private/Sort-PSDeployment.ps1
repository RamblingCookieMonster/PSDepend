function Sort-PSDependency {
    [cmdletbinding()]
    param(
        [object[]]$Dependencies
    )

    $Order = @{}
    Foreach($Dependency in $Dependencies)
    {
        if($Dependency.Dependencies.DeploymentName)
        {
            if(-not $Order.ContainsKey($Dependency.DeploymentName))
            {
                $Order.add($Dependency.DeploymentName, $Dependency.Dependencies.DeploymentName)
            }
        }
    }

    if($Order.Keys.Count -gt 0)
    {
        $DependencyOrder = Get-TopologicalSort $Order
        Sort-ObjectWithCustomList -InputObject $Dependencies -Property DependencyName -CustomList $DependencyOrder
    }
    else
    {
        $Dependencies
    }
}