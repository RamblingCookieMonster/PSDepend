<#
    .SYNOPSIS
        Download a file

    .DESCRIPTION
        Download a file

        Relevant Dependency metadata:
            DependencyName (Key): The key for this dependency is used as the URL. This can be overridden by 'Source'
            Name: Optional file name for the downloaded file.  Defaults to parsing filename from the URL
            Target: The folder to download this file to.  If a full path to a new file is used, this overrides any other file name.
            Source: Optional override for URL

    .EXAMPLE
        sqllite_dll = @{
            DependencyType = 'FileDownload'
            Source = 'https://github.com/RamblingCookieMonster/PSSQLite/blob/master/PSSQLite/x64/System.Data.SQLite.dll?raw=true'
            Target = 'C:\temp'
        }

        # Downloads System.Data.SQLite.dll to C:\temp

    .EXAMPLE
        'https://github.com/RamblingCookieMonster/PSSQLite/blob/master/PSSQLite/x64/System.Data.SQLite.dll?raw=true' = @{
            DependencyType = 'FileDownload'
            Target = 'C:\temp\sqlite.dll'
        }

        # Downloads System.Data.SQLite.dll to C:\temp\sqlite.dll
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]
    $Dependency
)

# Extract data from Dependency
    $DependencyName = $Dependency.DependencyName
    $Name = $Dependency.Name
    $Target = $Dependency.Target
    $Source = $Dependency.Source

    # Pick the URL
    if($Source)
    {
        $URL = $Source
    }
    else
    {
        $URL = $DependencyName
    }
    Write-Verbose "Using URL: $URL"

    $TargetParent = Split-Path $Target -Parent
    if( (Test-Path $TargetParent) -and -not (Test-Path $Target))
    {
        # They gave us a full path, don't parse the file name, use this!
        $Path = $Target
        Write-Verbose "Using [$Path] from `$Target"
    }
    elseif(Test-Path $Target -PathType Leaf)
    {
        # File exists.  We should download to temp spot, compare hashes, take action as appropriate.
        # For now, skip the file.
        Write-Verbose "Skipping existing file [$Target]"
        return
    }
    elseif(-not (Test-Path $Target))
    {
       # They gave us something that doesn't look like a new container for a new or exisrting file. Wat?
       Write-Error "Could not find target path [$Target]"
       return
    }
    else
    {
        # We have a target container, now find the name
        If($Name)
        {
            # explicit name
            $FileName = $Name
            Write-Verbose "Parsed file name [$FileName] from `$Name"
        }
        else
        {
            # This will need work.  Assume leaf is file.  If CGI exists in leaf, assume it is after the file
            $FileName = $URL.split('/')[-1]
            if($FileName -match '\?')
            {
                $FileName = $FileName.split('?')[0]
            }
            Write-Verbose "Parse file name [$FileName] from `$URL"
        }
        $Path = Join-Path $Target $FileName
    }
    Write-Verbose "Downloading [$URL] to [$Path]"

# We have the info, check for file, download it!
$webclient = New-Object System.Net.WebClient

# Future considerations:
    # Should we check for existing? And if we find it, still download file, and compare sha256 hash, replace if it does not match?
    # We should consider credentials at some point, but PSD1 does not lend itself to securely storing passwords

$webclient.DownloadFile($URL, $Path)