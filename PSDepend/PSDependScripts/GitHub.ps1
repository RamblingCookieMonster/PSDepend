<#
    .SYNOPSIS
        Installs a module from a GitHub repository.

    .DESCRIPTION
        Installs a module from a GitHub repository.

        Relevant Dependency metadata:
            DependencyName (Key): The key for this dependency is used as Name, if none is specified
            Name: Used to specify the GitHub repository name to download
            Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
            Target: The folder to download repo to. Created if it doesn't exist.
                "AllUsers" resolves to:
                    Windows: the "PowerShell\Modules" folder inside the system's ProgramFiles folder.
                    Other: the platform's SHARED_MODULES folder.
                "CurrentUser" resolves to:
                    Windows: the "PowerShell\Modules" folder inside the user's (My)Documents folder.
                    Other: the platform's USER_MODULES folder.
                It defaults to "AllUsers" on Windows in an elevated session and to "CurrentUser" otherwise.

                    
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

    .PARAMETER TargetType
        How we interpret your target:
            Standard: DEFAULT: Extract to target\name
            Exact:    Extract target\
            Parallel: Extract to target\name\version or target\name\branch\name depending on the version specified

    .PARAMETER Force
        If specified, delete target folder (as defined by TargetType) if it exists already
        Default: We copy to the target folder without removing

    .EXAMPLE
        Image a GitHub repository containing a PowerShell module with git tags named "1.0.0" and "0.1.0".

        @{
            'Dargmuesli/powershell-lib' = '1.0.0'
        }
        @{
            'Dargmuesli/powershell-lib' = 'latest'
        }
        @{
            'Dargmuesli/powershell-lib' = ''
        }
        These download version 1.0.0 to "powershell-lib\1.0.0"

        @{
            'Dargmuesli/powershell-lib' = '0.1.0'
        }
        This downloads version 0.1.0 to "powershell-lib\0.1.0"

        @{
            'Dargmuesli/powershell-lib' = 'master'
        }
        This downloads branch "master" (most recent commit version) to "powershell-lib"

    .EXAMPLE
        Image a GitHub repository containing a PowerShell module with no git tags.

        @{
            'Dargmuesli/powershell-lib' = 'latest'
        }
        @{
            'Dargmuesli/powershell-lib' = ''
        }
        @{
            'Dargmuesli/powershell-lib' = 'master'
        }
        These download branch "master" (most recent commit version) to "powershell-lib"

        @{
            'Dargmuesli/powershell-lib' = @{
                Version = 'latest'
                Parameters @{
                    TargetType = 'Parallel'
                }
            }
        }
        @{
            'Dargmuesli/powershell-lib' = @{
                Parameters @{
                    TargetType = 'Parallel'
                }
            }
        }
        @{
            'Dargmuesli/powershell-lib' = @{
                Version = 'master'
                Parameters @{
                    TargetType = 'Parallel'
                }
            }
        }
        These download branch "master" (most recent commit version) to "powershell-lib\master\powershell-lib"

        @{
            'Dargmuesli/powershell-lib' = @{
                Version = 'feature'
                Parameters @{
                    TargetType = 'Parallel'
                }
            }
        }
        This downloads branch "feature" (most recent commit version) to "powershell-lib\feature\powershell-lib"

    .EXAMPLE
        @{
            'powershell/demo_ci' = @{
                Version = 'latest'
                DependencyType = 'GitHub'
                Target = 'C:\T'
                Parameters = @{
                    ExtractPath = 'Assets/DscPipelineTools',
                                  'InfraDNS/Configs/DNSServer.ps1'
                    TargetType = 'Exact'
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

    [bool]$ExtractProject = $True,

    [ValidateSet('Parallel', 'Standard', 'Exact')]
    [string]$TargetType = 'Standard',

    [switch]$Force
)

$script:IsWindows = (-not (Get-Variable -Name "IsWindows" -ErrorAction "Ignore")) -or $IsWindows

Write-Verbose -Message "Examining GitHub dependency [$($Dependency.DependencyName)]"

# Extract data from dependency
$DependencyName = $Dependency.DependencyName
$Version = $Dependency.Version
$Target = $Dependency.Target
$NameParts = $DependencyName.Split("/")
$Name = $NameParts[1]

# Translate "" to "latest"
if($Version -eq "")
{
    $Version = "latest"
}

# Check if the version that should be used is a version number
if($Version -match "^\d+(?:\.\d+)+$")
{
    $Version = New-Object "System.Version" $Version
}

# Get system installation path
if($script:IsWindows)
{
    $AllUsersPath = Join-Path -Path $env:ProgramFiles -ChildPath "PowerShell\Modules"
}
else
{
    $AllUsersPath = [System.Management.Automation.Platform]::SelectProductNameForDirectory('SHARED_MODULES')
}

# Check if the MyDocuments folder path is accessible
try
{
    $MyDocumentsFolderPath = [Environment]::GetFolderPath("MyDocuments")
}
catch
{
    $MyDocumentsFolderPath = $null
}

# Get user installation path
if($script:IsWindows)
{
    if($MyDocumentsFolderPath)
    {
        $CurrentUserPath = Join-Path -Path $MyDocumentsFolderPath -ChildPath "PowerShell\Modules"
    }
    else
    {
        $CurrentUserPath = Join-Path -Path $HOME -ChildPath "Documents\PowerShell\Modules"
    }
}
else
{
    $CurrentUserPath = [System.Management.Automation.Platform]::SelectProductNameForDirectory('USER_MODULES')
}

# Set default target depending on admin permissions
if(-not $Target)
{
    if(($script:IsWindows) -And (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")))
    {
        $Target = $AllUsersPath
    }
    else
    {
        $Target = $CurrentUserPath
    }
}
else
{
    # Resolve scope keywords
    if($Target -Eq "CurrentUser")
    {
        $Target = $CurrentUserPath
    }
    elseif($Target -Eq "AllUsers")
    {
        $Target = $AllUsersPath
    }
}

# Search for an already existing version of the dependency
$Module = Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue
$ModuleExisting = $null
$ModuleExistingMatches = $false
$ExistingVersions = $null
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
    $ExistingVersions = $Module | Select-Object -ExpandProperty "Version"

    # Check if the version that is should be used is a version number
    if($Version -match "^\d+(?:\.\d+)+$")
    {
        :versionslocal foreach($ExistingVersion in $ExistingVersions)
        {
            switch($ExistingVersion.CompareTo($Version))
            {
                {@(-1, 1) -contains $_} {
                    Write-Verbose "For [$Name], the version you specified [$Version] does not match the already existing version [$ExistingVersion]"
                    $ShouldInstall = $true
                    break
                }
                0 {
                    Write-Verbose "For [$Name], the version you specified [$Version] matches the already existing version [$ExistingVersion]"
                    $ShouldInstall = $false
                    $ModuleExistingMatches = $True
                    break versionslocal
                }
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

            if($GitHubTags)
            {
                foreach($GitHubTag in $GitHubTags)
                {
                    if($GitHubTag.name -match "^\d+(?:\.\d+)+$" -and ($Version -match "^\d+(?:\.\d+)+$" -or $Version -eq "latest"))
                    {
                        $GitHubVersion = New-Object "System.Version" $GitHubTag.name

                        if($Version -Eq "latest")
                        {
                            $Version = $GitHubVersion
                        }

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
            else
            {
                break nullcheck
            }
        }
    }
    catch
    {
        # Repository does not seem to exist or a branch is the target
        $ShouldInstall = $False
        Write-Warning "Could not find module on GitHub: $_"
    }

    if($RemoteAvailable)
    {
        # Use the tag's link
        $URL = $GitHubTag.zipball_url
        if($ExistingVersions)
        {
            :versionsremote foreach($ExistingVersion in $ExistingVersions)
            {
                # Because a remote and a local version exist
                # Prevent a module from getting installed twice
                switch($ExistingVersion.CompareTo($GitHubVersion))
                {
                    {@(-1, 1) -contains $_} {
                        Write-Verbose "For [$Name], you have a different version [$ExistingVersion] compared to the version available on GitHub [$GitHubVersion]"
                        break
                    }
                    0 {
                        Write-Verbose "For [$Name], you already have the version [$ExistingVersion]"
                        $ModuleExistingMatches = $true
                        $ShouldInstall = $false
                        break versionsremote
                    }
                }
            }
        }
    }
    else
    {
        Write-Verbose "[$DependencyName] has no tags on GitHub or [$Version] is a branchname"
        # Translate version "latest" to "master"
        if($Version -eq "latest")
        {
            $Version = "master"
        }

        # Link for a .zip archive of the repository's branch
        $URL = "https://api.github.com/repos/$DependencyName/zipball/$Version"
        $ShouldInstall = $True
    }
}

# Install action needs to be wanted and logical
$ImportName = $Name
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
    if($script:IsWindows)
    {
        $Zipfile = (New-Object -com shell.application).NameSpace($OutFile)
        $Destination = (New-Object -com shell.application).NameSpace($OutPath)
        $Destination.CopyHere($Zipfile.Items())
    }
    else
    {
        # If not on Windows "Expand-Archive" should be available as PS version 6 is considered minimum.
        Expand-Archive $OutFile -DestinationPath $OutPath
    }

    # Remove the zip file
    Remove-Item $OutFile -Force -Confirm:$False

    $OutPath = (Get-ChildItem -Path $OutPath)[0].FullName
    $OutPath = (Rename-Item -Path $OutPath -NewName $Name -PassThru).FullName
    
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
        New-Item $Target -Force
    }

    $Destination = $null
    if ($TargetType -ne 'Exact')
    {
        $Target = Join-Path $Target $Name
    }

    if($TargetType -eq 'Exact')
    {
        $Destination = $Target
    }
    elseif($Version -match "^\d+(?:\.\d+)+$" -and $PSVersionTable.PSVersion -ge '5.0'  )
    {
        # For versioned GitHub tags
        $Destination = Join-Path $Target $Version
    }
    elseif(($Version -eq "latest") -and ($RemoteAvailable) -and $PSVersionTable.PSVersion -ge '5.0' )
    {
        # For latest GitHub tags
        $Destination = Join-Path $Target $GitHubVersion
    }
    elseif($PSVersionTable.PSVersion -ge '5.0' -and $TargetType -eq 'Parallel')
    {
        # For GitHub branches
        $Destination = Join-Path $Target $Version 
        $Destination = Join-Path $Destination $Name
    }
    else
    {
        $Destination = $Target
    }
    if($Force -and (Test-Path -Path $Destination))
    {
        Remove-Item -Path $Destination -Force -Recurse
    }

    Write-Verbose "Copying [$($ToCopy.Count)] items to destination [$Destination] with`nTarget [$Target]`nName [$Name]`nVersion [$Version]`nGitHubVersion [$GitHubVersion]"
    foreach($Item in $ToCopy)
    {
        Copy-Item -Path $Item -Destination $Destination -Force -Recurse
        $ImportName = $Destination
    }
    # Delete the temporary folder
    Remove-Item (Get-Item $OutPath).parent.FullName -Force -Recurse
    $ModuleExisting = $true
}

# Conditional import
if($ModuleExisting)
{
    Import-PSDependModule -Name $ImportName -Action $PSDependAction
}
elseif($PSDependAction -contains 'Import')
{
    Write-Warning "[$Name] at [$Destination] should be imported, but does not exist"
}

# Return true or false if Test action is wanted
if($PSDependAction -contains 'Test')
{
    return $ModuleExistingMatches
}

# Otherwise return null
return $null
