function Import-PSDependModule {
    [cmdletbinding()]
    param (
        $Name = $ModulePath,
        $Action = $PSDependAction
    )
    if($PSDependAction -contains 'Import')
    {
        Write-Verbose "Importing [$Name]"
        Import-Module $Name -Scope Global -Force 
    }
}