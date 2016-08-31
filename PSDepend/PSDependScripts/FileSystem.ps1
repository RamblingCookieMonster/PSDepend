<#
    .SYNOPSIS
        EXPERIMENTAL: Use Robocopy or Copy-Item for folder and file dependencies, respectively.

    .DESCRIPTION
        EXPERIMENTAL: Use Robocopy or Copy-Item for folder and file dependencies, respectively.

        Runs in the current session (i.e. as the current user)

        Relevant Dependency metadata:
            DependencyName (Key): The key for this dependency is used as the URL. This can be overridden by 'Source'
            Name: Optional file name for the downloaded file.  Defaults to parsing filename from the URL
            Target: The folder to copy the source to
            Source: The source folder or file to copy
            AddToPath: If specified, prepend the target's parent container to PATH

    .PARAMETER Deployment
        Dependency to run

    .PARAMETER PSDependAction
        Test, Install, or Import the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
              IMPORTANT: If a folder exists, return $True, whether the contents are the same or not
                         If a file exists, we check the hash
        Install: Install the dependency
        Import: Import the dependency 'Target'.  Override with ImportPath

    .PARAMETER ImportPath
        If specified with PSDependAction Import, we import this path, instead of Target, the default

    .PARAMETER Force
        If specified, and target is a folder, overwrite the target

    .PARAMETER Mirror
        If specified and the target is a folder, we effectively call robocopy /MIR (Can remove folders/files...)
#>
[cmdletbinding()]
param (
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]
    $Dependency,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install'),

    [string]$ImportPath
)

# Extract data from Dependency
    $DependencyName = $Dependency.DependencyName
    $Name = $Dependency.Name
    $Target = $Dependency.Target
    $Sources = $Dependency.Source

$TestOutput = @()
foreach($Source in $Sources)
{
    if(-not (Test-Path $Source))
    {
        Write-Error "Skipping $DependencyName, could not find source [$Sources] due to error:"
        Write-Error $_
        continue
    }
    $IsContainer = ( Get-Item $Source ).PSIsContainer
    
    # Resolve PSDrives.
    $Target = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Target)
    $Source = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Source)

    if($IsContainer)
    {
        $DependencyFolder = $Source
        if($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
        {
            if(Test-Path $Target)
            {
                $TestOutput += $true
            }
            else
            {
                $TestOutput += $false
            }
        }
        if($PSDependAction -contains 'Install')
        {
            # TODO: Add non Windows equivalent...
            [string[]]$Arguments = "/XO"
            $Arguments += "/E"
            if($Dependency.Parameters.Mirror -eq $True -or $Mirror)
            {
                $Arguments += "/PURGE"
            }

            Write-Verbose "Invoking ROBOCOPY.exe $Source $Target $Arguments"
            ROBOCOPY.exe $Source $Target @Arguments
        }
    }
    else
    {
        $DependencyFolder = Split-Path $Source -Parent
        $FileName = Split-Path $Source -Leaf
        $TargetFile = Join-Path $Target $FileName
        $SourceHash = ( Get-Hash $Source ).SHA256
        $TargetHash = $null
        if(Test-Path $Target -PathType Leaf)
        {
            $TargetHash = ( Get-Hash $Target -ErrorAction SilentlyContinue -WarningAction SilentlyContinue ).SHA256
            $TargetPath = $Target
        }
        elseif(Test-Path $TargetFile -PathType Leaf)
        {
            $TargetHash = ( Get-Hash $TargetFile -ErrorAction SilentlyContinue -WarningAction SilentlyContinue ).SHA256
            $TargetPath = $TargetFile
        }
        if($TargetHash -ne $SourceHash)
        {
            if($PSDependAction -contains 'Install')
            {
                Write-Verbose "Copying file [$Source] to [$Target]"
                Copy-Item -Path $Source -Destination $Target -Force
            }
            if($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
            {
                $TestOutput += $false
            }
        }
        else
        {
            Write-Verbose "Matching hash: [$Source] = [$TargetFile]"
            if($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
            {
                $TestOutput += $True
            }
        }
    }
}

if($PSDependAction -contains 'Test' -and $PSDependAction.count -eq 1)
{
    if($TestOutput -contains $false)
    {
        $false
    }
    else
    {
        $True
    }
}

$ToImport = $DependencyFolder
if($ImportPath)
{
    $ToImport = $ImportPath
}
Import-PSDependModule $ToImport