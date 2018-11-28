<#
.SYNOPSIS
Compares two versions and find whether they're equal, or one is newer than the other.

.DESCRIPTION
The Compare-SemVerVersion allows the comparison of SemVer 2.0 versions (including prerelease identifiers)
as documented on semver.org
The result will be = if the versions are equivalent, > if the reference version takes precedence, or < if the
difference version wins.

.PARAMETER ReferenceVersion
The string version you would like to test.

.PARAMETER DifferenceVersion
The other string version you would like to compare agains the reference.

.EXAMPLE
Compare-SemVerVersion -ReferenceVersion '0.2.3.546-alpha.201+01012018' -DifferenceVersion '0.2.3.546-alpha.200'
# >
Compare-SemVerVersion -ReferenceVersion '0.2.3.546-alpha.201+01012018' -DifferenceVersion '0.2.3.546-alpha.202'
# <

.EXAMPLE
Compare-SemVerVersion -ReferenceVersion '0.2.3.546-alpha.201+01012018' -DifferenceVersion '0.2.3.546-alpha.201+01012015'
# =

.NOTES
Worth noting that the documentaion of SemVer versions should follow this logic (from semver.org)
1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0.
#>
function Compare-SemVerVersion {
    [CmdletBinding()]
    [OutputType([string])]
    Param (
        [Parameter(
            Mandatory
        )]
        [String]
        $ReferenceVersion,

        [Parameter(
            Mandatory
        )]
        [String]
        $DifferenceVersion
    )

    $refVersion = Get-SemVerFromString -VersionString $ReferenceVersion -ErrorAction Stop
    $diffVersion = Get-SemVerFromString -VersionString $DifferenceVersion -ErrorAction Stop

    # Compare Version first
    if ($refVersion.Version -eq $diffVersion.Version) {
        if (!$refVersion.Prerelease -and $diffVersion.Prerelease) {
            '>'
        }
        elseif ($refVersion.Prerelease -and !$diffVersion.Prerelease) {
            '<'
        }
        elseif (!$diffVersion.Prerelease -and !$refVersion.Prerelease) {
            '='
        }
        elseif ($refVersion.Prerelease -eq $diffVersion.Prerelease) {
            '='
        }
        else {
            $resultSoFar = '='

            foreach ($index in 0..($refVersion.PrereleaseArray.count - 1)) {
                $refId = ($refVersion.PrereleaseArray[$index] -as [uint64])
                $diffId = ($diffVersion.PrereleaseArray[$index] -as [uint64])
                if ($refId -and $diffId) {
                    if ($refid -gt $diffId) { return '>'}
                    elseif ($refId -lt $diffId) { return '<'}
                    else {
                        Write-Debug "Ref identifier at index = $index are equals, moving onto next"
                    }
                }
                else {
                    $refId = [char[]]$refVersion.PrereleaseArray[$index]
                    $diffId = [char[]]$diffVersion.PrereleaseArray[$index]
                    foreach ($charIndex in 0..($refId.Count - 1)) {
                        if ([int]$refId[$charIndex] -gt [int]$diffId[$charIndex]) {
                            return '>'
                        }
                        elseif ([int]$refId[$charIndex] -lt [int]$diffId[$charIndex]) {
                            return '<'
                        }

                        if ($refId.count -eq $charIndex + 1 -and $refId.count -lt $diffId.count) {
                            return '>'
                        }
                        elseif ($diffId.count -eq $index + 1 -and $refId.count -gt $diffId.count) {
                            return '<'
                        }
                    }
                }

                if ($refVersion.PrereleaseArray.count -eq $index + 1 -and $refVersion.PrereleaseArray.count -lt $diffVersion.PrereleaseArray.count) {
                    return '<'
                }
                elseif ($diffVersion.PrereleaseArray.count -eq $index + 1 -and $refVersion.PrereleaseArray.count -gt $diffVersion.PrereleaseArray.count) {
                    return '>'
                }
            }
            return $resultSoFar
        }
    }
    elseif ($refVersion.Version -gt $diffVersion.Version) {
        '>'
    }
    else {
        '<'
    }
}