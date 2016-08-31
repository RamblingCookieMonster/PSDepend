function Import-PSDependModule {
    [cmdletbinding()]
    param (
        [string[]]$Name = $ModulePath,
        $Action = $PSDependAction
    )
    if($PSDependAction -contains 'Import')
    {
        foreach($Mod in $Name)
        {
            Write-Verbose "Importing [$Mod]"
            Import-Module -Name $Mod -Scope Global -Force 
        }
    }
}