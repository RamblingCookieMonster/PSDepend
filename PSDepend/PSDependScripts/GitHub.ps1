<#
    .SYNOPSIS
        Installs a module from a GitHub repository.

    .DESCRIPTION
        Installs a module from a GitHub repository.

        Relevant Dependency metadata:
            DependencyName (Key): The key for this dependency is used as Name, if none is specified
            Name: Used to specify the GitHub repository name to download
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
            Target: The folder to download repo to.  Defaults to "$ENV:USERPROFILE\Documents\WindowsPowerShell\Modules".  Created if it doesn't exist.

    .NOTES
        A huge thanks to Doug Finke for the idea and some code and to Jonas Thelemann for a rewrite for releases!
            https://github.com/dfinke/InstallModuleFromGitHub
            https://github.com/dargmuesli

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency
        Import: Import the dependency

    .PARAMETER ExtractPath
        Extract only these specified file(s) or folder(s) to the target.

    .PARAMETER ExtractProject
        Parse the GitHub repository for a common PowerShell project hierarchy and extract only the project folder

        Example:  ramblingcookiemonster/psslack looks like this:
                  PSSlack/         Repo root
                    PSSlack/       Module root
                      PSSlack.psd1 Module manifest
                  Tests/

                  In this case, we would extract PSSlack/PSSlack only

        Example:  bundyfx/vamp looks like this:
                  vamp/            Repo root (also, module root)
                    vamp.psd1      Module manifest

                  In this case, we would extract the whole root vamp folder

    .EXAMPLE
        @{
            'Dargmuesli/powershell-lib' = '0.1.0'
        }

        # Download version 0.1.0 of powershell-lib by Dargmuesli on GitHub

    .EXAMPLE
        @{
            'Dargmuesli/powershell-lib' = ''
        }

        # Download latest version of powershell-lib by Dargmuesli on GitHub

    .EXAMPLE
        @{
            'powershell/demo_ci' = @{
                Version = 'latest'
                DependencyType = 'GitHub'
                Parameters = @{
                    ExtractPath = 'Assets/DscPipelineTools',
                                  'InfraDNS/Configs/DNSServer.ps1'
                }
            }
        }

        # Download the latest version of demo_ci by powershell on GitHub
        # Extract repo-root/Assets/DscPipelineTools to the target
        # Extract repo-root/InfraDNS/Configs/DNSServer.ps1 to the target
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install'),

    [string[]]$ExtractPath,
    
    [bool]$ExtractProject = $True
)

Write-Verbose -Message "Examining GitHub dependency [$DependencyName]"

# Extract data from dependency
$DependencyName = $Dependency.DependencyName
$Target = $Dependency.Target
$NameParts = $Dependency.Name.Split("/")
$Name = $NameParts[1]
$Version = $Dependency.Version

$Module = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue
$ModuleExisting = $null
$ExistingVersion = $null
$ShouldInstall = $false
$URL = $null

if(-not $Target)
{
    $Target = "$ENV:USERPROFILE\Documents\WindowsPowerShell\Modules\"
}

if($Module)
{
    $ModuleExisting = $true
}
else
{
    $ModuleExisting = $false
}

if($ModuleExisting)
{
    Write-Verbose "Found existing module [$Name]"
    $ExistingVersion = $Module | Measure-Object -Property Version -Maximum | Select-Object -ExpandProperty Maximum

    if($Version -match "^\d+(?:\.\d+)+$") {
        switch($ExistingVersion.CompareTo($Version))
        {
            {@(-1, 1) -contains $_} {
                Write-Verbose "For [$Name], the version you specified [$ExistingVersion] does not match the already existing version [$ExistingVersion]"
                $ShouldInstall = $true
                break
            }
            0 {
                Write-Verbose "For [$Name], the version you specified [$ExistingVersion] matches the already existing version [$ExistingVersion]"
                break
            }
        }
    }
    else
    {
        $ShouldInstall = $true
    }
}
else
{
    $ShouldInstall = $true
}

if($ShouldInstall)
{
    $LatestRelease = $null

    try
    {
        $LatestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$DependencyName/releases/latest"
    }
    catch
    {
        # Nothing
    }

    if($LatestRelease)
    {
        $GitHubVersion = New-Object "System.Version" $LatestRelease.tag_name

        if ($ExistingVersion)
        {
            switch($ExistingVersion.CompareTo($GitHubVersion))
            {
                1 {
                    Write-Verbose "For [$Name], you have a more recent version [$ExistingVersion] than the version available on GitHub [$ExistingVersion]"
                    $ShouldInstall = $false
                    break
                }
                0 {
                    Write-Verbose "For [$Name], you already have the lastest version [$ExistingVersion]"
                    $ShouldInstall = $false
                    break
                }
                -1 {
                    Write-Verbose "For [$Name], you have an older version [$ExistingVersion] than the version available on GitHub [$ExistingVersion]"
                    $URL = $LatestRelease.zipball_url
                    break
                }
            }
        }
        else
        {
            $URL = $LatestRelease.zipball_url
        }
    }
    else
    {
        Write-Verbose "[$DependencyName] has no releases"

        if($Version -Eq "latest")
        {
            $Version = "master"
        }

        $URL = "https://api.github.com/repos/$DependencyName/zipball/$Version"
    }
}

if(($PSDependAction -contains 'Install') -and $ShouldInstall)
{
    $OutPath = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().guid)
    New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
    $OutFile = Join-Path $OutPath "$Version.zip"
    Invoke-RestMethod -Uri $URL -OutFile $OutFile

    if(-not (Test-Path $OutFile))
    {
        Write-Error "Could not download [$URL] to [$OutFile]. See error details and verbose output for more information"
        return
    }
    
    $Zipfile = (New-Object -com shell.application).NameSpace($OutFile)
    $Destination = (New-Object -com shell.application).NameSpace($OutPath)
    $Destination.CopyHere($Zipfile.Items())

    Remove-Item $OutFile -Force -Confirm:$False

    $OutPath = (Get-ChildItem -Path $OutPath)[0].FullName
    
    if($ExtractPath)
    {
        [string[]]$ToCopy = foreach($RelativePath in $ExtractPath)
        {
            $AbsolutePath = Join-Path $OutPath $RelativePath
            if(-not (Test-Path $AbsolutePath))
            {
                Write-Warning "Expected ExtractPath [$RelativePath], did not find at [$AbsolutePath]"
            }
            else
            {
                $AbsolutePath
            }
        }
    }
    elseif($ExtractProject)
    {
        $ProjectDetails = Get-ProjectDetail -Path $OutPath
        [string[]]$ToCopy = $ProjectDetails.Path
    }
    else
    {
        [string[]]$ToCopy = $OutPath
    }
    
    Write-Verbose "ToCopy: $ToCopy"
    
    if(-not (Test-Path $Target))
    {
        mkdir $Target -Force
    }
    foreach($Item in $ToCopy)
    {
        Copy-Item -Path $Item -Destination "$Target$Name" -Force -Confirm:$False -Recurse
    }
    
    Remove-Item (Get-Item $OutPath).parent.FullName -Force -Recurse
}

Import-PSDependModule -Name $Name -Action $PSDependAction

if($PSDependAction -contains 'Test')
{
    return $ModuleExisting
}

return $null
