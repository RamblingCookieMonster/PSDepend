<#
    .SYNOPSIS
        Installs a module from a PowerShell repository like the PowerShell Gallery.

    .DESCRIPTION
        Installs a module from a PowerShell repository like the PowerShell Gallery

    .PARAMETER Name
        Module to install

    .PARAMETER Version
        Version to install.  Defaults to latest.

    .PARAMETER PSRepository
        PSRepository to download from.  Defaults to PSGallery
#>
[cmdletbinding()]
param(
    #[ValidateScript({ $_.PSObject.TypeNames[0] -eq 'PSDepend.Dependency' })]
    #[psobject[]]$Dependency,

    [Parameter(Mandatory)]
    [string]$Name,

    [string]$Version,

    [string]$Repository = 'PSGallery',

    [string]$Target = 'AllUsers' # Can be allusers/currentusers, or a path to save module to
)

Write-Verbose -Message "Getting dependency [$name] from PowerShell repository [$Repository]"

# Validate that $target has been setup as a valid PowerShell repository
$validRepo = Get-PSRepository -Name $Repository -Verbose:$false -ErrorAction SilentlyContinue
if (-not $validRepo) {
    throw "[$Repository] has not been setup as a valid PowerShell repository."
}

$params = @{
    Name = $Name
    Repository = $Repository
    Verbose = $VerbosePreference
}

if( $Version -and $Version -ne 'latest')
{
    $Params.add('RequiredVersion',$RequiredVersion)
}

if('AllUsers', 'CurrentUser' -contains $Scope)
{
    Install-Module @params -Scope $Scope
}
elseif(Test-Path $Scope -PathType Container)
{
    Save-Module @params -Path $Scope
}
