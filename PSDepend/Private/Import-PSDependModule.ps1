function Import-PSDependModule {
    [cmdletbinding()]
    param (
        $Name = $ModulePath,
        $Action = $PSDependAction
    )
    if($PSDependAction -contains 'Import')
    {
        Write-Verbose "Importing [$Name]"
        Import-Module -Name $Name -Scope Global -Force 
    }
}