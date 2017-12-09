function Import-PSDependModule {
    [cmdletbinding()]
    param (
        [string[]]$Name = $ModulePath,
        $Action = $PSDependAction,
        [string] $Version
    )
    if($PSDependAction -contains 'Import')
    {
        foreach($Mod in $Name)
        {
            Write-Verbose "Importing [$Mod]"
            $importParams = @{
                Name = $Mod
                Scope = 'Global'
                Force = $true
            }
            if ($Version -and $Version -ne 'latest') {
                $importParams.add('RequiredVersion',$Version)
            }
            Import-Module @importParams
        }
    }
}