function test-variable {
    [cmdletbinding()]
    param(
        $X

    )
    "0"
    Get-Variable -name ModuleRoot -Scope 0
    "1"
    Get-Variable -name ModuleRoot -Scope 1
    "2"
    Get-Variable -name ModuleRoot -Scope 2

    'script'
    Get-Variable -Name ModuleRoot -Scope Script
    'global'
    Get-Variable -Name ModuleRoot -Scope Global
        'local'
    Get-Variable -Name ModuleRoot -Scope local
}