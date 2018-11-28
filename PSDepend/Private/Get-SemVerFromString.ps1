function Get-SemVerFromString
{
    <#
    .SYNOPSIS
    Private function to parse a string to a SemVer 2.0 custom object, but with added Revision number common to .Net world (and Choco Packages)

    .DESCRIPTION
    This function parses the string of a version into an object composed of a [System.Version] object (Major, Minor, Patch, Revision)
    plus the pre-release identifiers and Build Metadata. The PreRelease metadata is also made available as an array to ease the
    version comparison.

    .PARAMETER VersionString
    String representation of the Version to Parse.

    .EXAMPLE
    Get-SemVerFromString -VersionString '1.6.24.256-rc1+01012018'

    .EXAMPLE
    Get-SemVerFromString -VersionString '1.6-alpha.13.24.15'

    .NOTES
    The function returns a PSObject of PSTypeName Package.Version
    #>
    [CmdletBinding()]
    [OutputType([PSobject])]

    Param (
        [String]
        [ValidatePattern(
            "^\d+[\.\d]+(-.*)*$"
        )]
        $VersionString
    )

    # Based on SemVer 2.0 but adding Revision (common in .Net/NuGet/Chocolatey packages) https://semver.org
    if ($VersionString -notmatch '-')
    {
        [System.Version]$version, $BuildMetadata = $VersionString -split '\+', 2
    }
    else
    {
        [System.Version]$version, [String]$Tag = $VersionString -split '-', 2
        $PreRelease, $BuildMetadata = $Tag -split '\+', 2
    }

    $PreReleaseArray = $PreRelease -split '\.'

    [psobject]@{
        PSTypeName      = 'Package.Version'
        Version         = $version
        Prerelease      = $PreRelease
        Metadata        = $BuildMetadata
        PrereleaseArray = $PreReleaseArray
    }
}