if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

$PSVersion = $PSVersionTable.PSVersion.Major

# Verbose output for non-master builds on appveyor
# Handy for troubleshooting.
# Splat @Verbose against commands as needed (here or in pester tests)
    # $Verbose = @{}
    # if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose")
    # {
    #     $Verbose.add("Verbose",$True)
    # }

$TestDepends = Join-Path $ENV:BHProjectPath Tests\DependFiles

InModuleScope PSDepend {
    Describe Get-SemVerFilterFromString {

        Context 'Unsupported filters' {

            $UnsupportedFilters = @(
                # version on the right can't be parsed properly
                @{FailingFilter = '(-lt 2.0 -and -gt 1.8) -or -eq 1.2.3'} # version on the right can't be parsed properly
                ,@{FailingFilter = '(-lt "2.0" -and -gt "1.8") -or -eq 1.2.3'}
                ,@{FailingFilter = '(-eq 1.2.3 -or -eq 1.6.2) -or -gt 3.0.9'}
            )

            It 'Will fail if using filter like: <FailingFilter> ' -TestCases $UnsupportedFilters {
                Param ($FailingFilter)

                {(Get-SemVerFilterFromString $FailingFilter).ToString() } | Should -Throw
            }
        }


        context 'Expected Filter' {
            $ExpectedFilterTests = @(
                @{FilterString = '-gt 1.0.0'; Filter = "(`">`".GetEnumerator()  -contains (Compare-SemVerVersion `$_.Version '1.0.0'))" }
                ,@{FilterString = '-lt 1.0.0'; Filter = "(`"<`".GetEnumerator()  -contains (Compare-SemVerVersion `$_.Version '1.0.0'))" }
                ,@{FilterString = '-eq 1.0.0'; Filter = "(`"=`".GetEnumerator()  -contains (Compare-SemVerVersion `$_.Version '1.0.0'))" }
                ,@{FilterString = '-ge 1.0.0'; Filter = "(`">=`".GetEnumerator() -contains (Compare-SemVerVersion `$_.Version '1.0.0'))" }
                ,@{FilterString = '-le 1.0.0'; Filter = "(`"<=`".GetEnumerator() -contains (Compare-SemVerVersion `$_.Version '1.0.0'))" }
                ,@{FilterString = '(-lt 2.0 -and -gt 1.8) -or -eq "1.2.3"'; Filter = "( (`"<`".GetEnumerator()  -contains (Compare-SemVerVersion `$_.Version '2.0')) -and (`">`".GetEnumerator()  -contains (Compare-SemVerVersion `$_.Version '1.8')) ) -or (`"=`".GetEnumerator()  -contains (Compare-SemVerVersion `$_.Version '1.2.3'))" }

            )

            It 'Should ensure Get-SemVerFilterFromString <FilterString> returns <Filter>' -TestCases $ExpectedFilterTests {
                Param($FilterString, $Filter)

                (Get-SemVerFilterFromString $FilterString).ToString() | Should -be $Filter
            }
        }

        $TestCases = @(
            @{ RefVersion = '1.0.1'; FilterString = '-gt 1.0.0'; ExpectedResult = $true }
            ,@{ RefVersion = '1.0.0-pre1'; FilterString = '-lt "1.0.0"'; ExpectedResult = $true }
            ,@{ RefVersion = '1.0.0'; FilterString = '-eq "1.0.0"'; ExpectedResult = $true }
            ,@{ RefVersion = '1.0.0'; FilterString = '-ge "1.0.0"'; ExpectedResult = $true }
            ,@{ RefVersion = '1.0.0'; FilterString = '-le "1.0.0"'; ExpectedResult = $true }
            ,@{ RefVersion = '1.0.0'; FilterString = '-lt "1.0.1" -and -gt "0.9.9"'; ExpectedResult = $true }
            ,@{ RefVersion = '1.0.1'; FilterString = '-lt "1.0.1" -and -gt "0.9.9"'; ExpectedResult = $false }
            ,@{ RefVersion = '1.2.3'; FilterString = '(-lt "2.0" -and -gt "1.8" -or -eq "1.2.3")'; ExpectedResult = $true }
            ,@{ RefVersion = '1.2.3'; FilterString = '-eq "1.2.3" -or (-lt "2.0" -and -gt "1.8")'; ExpectedResult = $true }
            ,@{ RefVersion = '2.1'; FilterString = '(-lt "2.0" -and -gt "1.8") -or (-eq "1.2.3" -or -eq "3.2.1")'; ExpectedResult = $false }
            ,@{ RefVersion = '1.2.3'; FilterString = '(-lt "2.0" -and -gt "1.8") -or (-eq 1.2.3 -or -eq "1.1.1")'; ExpectedResult = $true }
            ,@{ RefVersion = '1.2.3'; FilterString = '(-lt "2.0" -and -gt "1.8") -or -eq "1.2.3"'; ExpectedResult = $true }
            ,@{ RefVersion = '1.2.3'; FilterString = '(-lt "2.0" -and -gt "1.8") -and -gt "1.2.3"'; ExpectedResult = $false }
            ,@{ RefVersion = '1.2.3'; FilterString = '(-lt "2.0" -and -gt "1.8") -and (-gt "1.2.3" -or -gt "3.2.1")'; ExpectedResult = $false }
            ,@{ RefVersion = '1.2.3'; FilterString = '(-lt 2.0 -and -gt "1.8") -and -gt "1.2.3" -or -gt "3.2.1"'; ExpectedResult = $false }
        )

        Context 'SemVer Filter works' {


            It 'Should ensure <RefVersion> <FilterString> is <ExpectedResult>' -TestCases $TestCases {
                Param ($RefVersion, $FilterString, $ExpectedResult )
                $Filter = Get-SemVerFilterFromString $FilterString
                $result = if( (@{Version = $RefVersion} | Where-Object $Filter))
                {
                    $true
                }
                else
                {
                    $false
                }
                $result | Should -be $ExpectedResult
            }
        }
    }
}
