function Sort-PSDependency {
    [cmdletbinding()]
    param(
        [object[]]$Dependencies
    )

    $Order = @{}
    Foreach($Dependency in $Dependencies)
    {
        if($Dependency.Dependencies.DependencyName)
        {
            if(-not $Order.ContainsKey($Dependency.DependencyName))
            {
                $Order.add($Dependency.DependencyName, $Dependency.Dependencies.DependencyName)
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