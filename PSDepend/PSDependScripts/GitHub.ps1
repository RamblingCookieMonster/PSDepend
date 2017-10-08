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
        A huge thanks to Doug Finke for the idea and some code and to Jonas Thelemann for a rewrite for tags!
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
$Version = $Dependency.Version
$Target = $Dependency.Target
$NameParts = $Dependency.Name.Split("/")
$Name = $NameParts[1]

# Translate "" to "latest"
if($Version -eq "")
{
    $Version = "latest"
}

# Check if the version that is should be used is a version number
if($Version -match "^\d+(?:\.\d+)+$") {
    $Version = New-Object "System.Version" $Version
}

# Set default target
if(-not $Target)
{
    $Target = "$ENV:USERPROFILE\Documents\WindowsPowerShell\Modules\"
}

# Search for an already existing version of the dependency
$Module = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue
$ModuleExisting = $null
$ExistingVersion = $null
$ShouldInstall = $false
$RemoteAvailable = $false
$URL = $null

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

    # Check if the version that is should be used is a version number
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
        # The version that is to be used is probably a GitHub branch name
        $ShouldInstall = $true
    }
}
else
{
    Write-Verbose "Did not find existing module [$Name]"
    $ShouldInstall = $true
}

# Skip the case when the version that is to be used already exists
if($ShouldInstall)
{
    # API-fetch the tags on GitHub
    $GitHubVersion = $null
    $GitHubTag = $null
    $Page = 0

    try
    {
        :nullcheck while($GitHubVersion -Eq $null)
        {
            $Page++
            $GitHubTags = Invoke-RestMethod -Uri "https://api.github.com/repos/$DependencyName/tags?per_page=100&page=$Page"

            foreach($GitHubTag in $GitHubTags)
            {
                if($GitHubTag.name -match "^\d+(?:\.\d+)+$")
                {
                    $GitHubVersion = New-Object "System.Version" $GitHubTag.name

                    switch($Version.CompareTo($GitHubVersion))
                    {
                        -1 {
                            # Version is older compared to the GitHub version, continue searching
                            break
                        }
                        0 {
                            Write-Verbose "For [$Name], a matching version [$Version] has been found in the GitHub tags"
                            $RemoteAvailable = $true
                            break nullcheck
                        }
                        1 {
                            # Version is newer compared to the GitHub version, which means we can stop searching (given version history is reasonable)
                            break nullcheck
                        }
                    }
                }
            }
        }
    }
    catch
    {
        # Stupid, but needed error handler for Invoke-RestMethod
    }

    if($RemoteAvailable)
    {
        if ($ExistingVersion)
        {
            # A remote and a local version exist
            switch($ExistingVersion.CompareTo($GitHubVersion))
            {
                {@(-1, 1) -contains $_} {
                    Write-Verbose "For [$Name], you have a different version [$ExistingVersion] compared to the version available on GitHub [$GitHubVersion]"
                    $URL = $GitHubTag.zipball_url
                    break
                }
                0 {
                    Write-Verbose "For [$Name], you already have the version [$ExistingVersion]"
                    $ShouldInstall = $false
                    break
                }
            }
        }
        else
        {
            # A remote but no local version exist, so use the tags link
            $URL = $GitHubTag.zipball_url
        }
    }
    else
    {
        Write-Verbose "[$DependencyName] has no tags on GitHub"

        # Translate version "latest" to "master"
        if($Version -Eq "latest")
        {
            $Version = "master"
        }

        # Link for a .zip archive of the repository's branch
        $URL = "https://api.github.com/repos/$DependencyName/zipball/$Version"
    }
}

# Install action needs to be wanted and logical
if(($PSDependAction -contains 'Install') -and $ShouldInstall)
{
    # Create a temporary directory and download the repository to it
    $OutPath = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().guid)
    New-Item -ItemType Directory -Path $OutPath -Force | Out-Null
    $OutFile = Join-Path $OutPath "$Version.zip"
    Invoke-RestMethod -Uri $URL -OutFile $OutFile

    if(-not (Test-Path $OutFile))
    {
        Write-Error "Could not download [$URL] to [$OutFile]. See error details and verbose output for more information"
        return
    }
    
    # Extract the zip file
    $Zipfile = (New-Object -com shell.application).NameSpace($OutFile)
    $Destination = (New-Object -com shell.application).NameSpace($OutPath)
    $Destination.CopyHere($Zipfile.Items())

    # Remove the zip file
    Remove-Item $OutFile -Force -Confirm:$False

    $OutPath = (Get-ChildItem -Path $OutPath)[0].FullName
    
    if($ExtractPath)
    {
        # Filter only the contents wanted
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
        # Filter only the project contents
        $ProjectDetails = Get-ProjectDetail -Path $OutPath
        [string[]]$ToCopy = $ProjectDetails.Path
    }
    else
    {
        # Use the standard download path
        [string[]]$ToCopy = $OutPath
    }
    
    Write-Verbose "Contents that will be copied: $ToCopy"
    
    # Copy the contents to their target
    if(-not (Test-Path $Target))
    {
        mkdir $Target -Force
    }
    foreach($Item in $ToCopy)
    {
        $Destination = $null

        if($Version -match "^\d+(?:\.\d+)+$") {
            # For versioned GitHub tags
            $Destination = "$Target$Name\$Version"
        }
        elseif(($Version -eq "latest") -and ($RemoteAvailable))
        {
            # For latest GitHub tags
            $Destination = "$Target$Name\$GitHubVersion"
        }
        else
        {
            # For GitHub branches
            $Destination = "$Target$Name\$Version\$Name"
        }

        Copy-Item -Path $Item -Destination $Destination -Force -Confirm:$False -Recurse
    }
    
    # Delete the temporary folder
    Remove-Item (Get-Item $OutPath).parent.FullName -Force -Recurse

    $ModuleExisting = $true
}

# Conditional import
if($ModuleExisting -and ($PSDependAction -contains 'Import'))
{
    Import-PSDependModule -Name $Name -Action $PSDependAction
}
elseif($PSDependAction -contains 'Import')
{
    Write-Warning "[$Name] should be imported, but does not exist"
}

# Return true or false if Test action is wanted
if($PSDependAction -contains 'Test')
{
    return $ModuleExisting
}

# Otherwise return null
return $null
