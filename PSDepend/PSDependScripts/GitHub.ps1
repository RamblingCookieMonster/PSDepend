<#
    .SYNOPSIS
        EXPERIMENTAL: Download a GitHub repository

    .DESCRIPTION
        Download a GitHub repository

        The Git dependency type requires git.exe.  The FileDownload type would just pull an archive down.
        This type will...
            download a repository via HTTP,
            extract it,
            optionally, select out a specific subfolder for PowerShell based projects.

        Relevant Dependency metadata:
            DependencyName (Key): The key for this dependency is used as Name, if none is specified
            Name: Used to specify the GitHub entity/reponame to download
            Target: The folder to download repo to.  Defaults to "$ENV:USERPROFILE\Documents\WindowsPowerShell\Modules".  Created if it doesn't exist.
            Version:  Specify a branch name or commit hash to download

    .NOTES
        A huge thanks to Doug Finke for the idea and some code!
            https://github.com/dfinke/InstallModuleFromGitHub

    .PARAMETER PSDependAction
        Test or Install the module.  Defaults to Install

        NOTE: Test is currently not implemented.

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency

    .PARAMETER ExtractPath
        Download the repo, and extract only these specified file(s) or folder(s) to the target.  Defaults to $True

    .PARAMETER ExtractProject
        Downoad the repo, parse it for a common PowerShell project hierarchy, and extract only the project folder

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
            'bundyfx/vamp' = 'master'
        }

        # Download the master branch of vamp from bundyfx on GitHub

    .EXAMPLE

        @{
            'powershell/demo_ci' = @{
                Version = 'master'
                DependencyType = 'GitHub'
                Parameters = @{
                    ExtractPath = 'Assets/DscPipelineTools',
                                  'InfraDNS/Configs/DNSServer.ps1'
                }
            }
        }

        # Download the master branch of demo_ci from powershell on GitHub
        # Extract repo-root/Assets/DscPipelineTools to the target
        # Extract repo-root/InfraDNS/Configs/DNSServer.ps1 to the target
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]
    $Dependency,

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install'),

    [bool]$ExtractProject = $True,

    [string[]]$ExtractPath
)

# Extract data from Dependency
    $DependencyName = $Dependency.DependencyName
    if(-not ($Name = $Dependency.Name))
    {
        $Name = $DependencyName
    }
    $Target = $Dependency.Target
    if(-not $Target)
    {
        $Target = "$ENV:USERPROFILE\Documents\WindowsPowerShell\Modules\"
    }

    $Source = $Dependency.Source

    # Default to master branch
    if(-not ($Version = $Dependency.Version))
    {
        $Version = 'master'
    }

# entity/project?
if( ($Name -split '/' ).count -eq 2 )
{
    $URL = 'https://github.com/{0}/archive/{1}.zip' -f $Name, $Version
}
else #URL
{
    $URL = $Name
}
$GitHubProject = $URL.split('/')[-3]

$OutPath = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().guid)
$null = New-Item -ItemType Directory -Path $OutPath -Force
$OutFile= Join-Path $OutPath "$Version.zip"
Invoke-RestMethod $URL -OutFile $OutFile

#TODO: platform specific bits, e.g. System.IO.Compression.ZipFile for core
    Unblock-File $OutFile -Confirm:$False

    # Compat with older .net...
    $Zipfile = (New-Object -com shell.application).NameSpace($OutFile)
    $Destination = (New-Object -com shell.application).NameSpace($OutPath)
    $Destination.CopyHere($Zipfile.Items())

$GitHubFolder = Rename-Item (Join-Path $OutPath "$GitHubProject-$Version") $GitHubProject -PassThru

Remove-Item $OutFile -Force -Confirm:$False

if($ExtractPath)
{
    [string[]]$ToCopy = foreach($RelativePath in $ExtractPath)
    {
        $AbsolutePath = Join-Path $GitHubFolder $RelativePath
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
    $ProjectDetails = Get-ProjectDetail -Path $GitHubFolder
    [string[]]$ToCopy = $ProjectDetails.Path
}
else
{
    [string[]]$ToCopy = $GitHubFolder
}

Write-Verbose "ToCopy: $ToCopy"

#TODO: Implement test and import PSDependActions.
if($PSDependAction -contains 'install')
{
    if(-not (Test-Path $Target))
    {
        mkdir $Target -Force
    }
    foreach($Item in $ToCopy)
    {
        Copy-Item -Path $Item -Destination $Target -Force -Confirm:$False -Recurse
    }
}

Remove-Item $OutPath -Force -Recurse