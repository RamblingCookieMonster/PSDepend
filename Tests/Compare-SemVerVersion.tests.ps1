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
    Describe Compare-SemVerVersion {

        $TestCases = @(
            # test as per https://semver.org/#spec-item-11
            @{RefVersion = '1.0.0-alpha'; DiffVersion = '1.0.0-alpha.1'; ExpectedResult = '<'}
            @{RefVersion = '1.0.0-alpha.1'; DiffVersion = '1.0.0-alpha.beta'; ExpectedResult = '<'}
            @{RefVersion = '1.0.0-alpha.beta'; DiffVersion = '1.0.0-beta'; ExpectedResult = '<'}
            @{RefVersion = '1.0.0-beta'; DiffVersion = '1.0.0-beta.2'; ExpectedResult = '<'}
            @{RefVersion = '1.0.0-beta.2'; DiffVersion = '1.0.0-beta.11'; ExpectedResult = '<'}
            @{RefVersion = '1.0.0-beta.11'; DiffVersion = '1.0.0-rc.1'; ExpectedResult = '<'}
            @{RefVersion = '1.0.0-rc.1'; DiffVersion = '1.0.0'; ExpectedResult = '<'}

            # Other tests
            @{RefVersion = '1.2'; DiffVersion = '1.2-rc1'; ExpectedResult = '>'}
            @{RefVersion = '1.2'; DiffVersion = '1.2'; ExpectedResult = '='}
            @{RefVersion = '1.2+metadata'; DiffVersion = '1.2'; ExpectedResult = '='}
            @{RefVersion = '1.2-beta'; DiffVersion = '1.2'; ExpectedResult = '<'}
        )
        Context 'Default' {


            It 'Should ensure <RefVersion> <expectedResult> <DiffVersion>' -TestCases $TestCases {
                Param ($RefVersion, $DiffVersion, $ExpectedResult )
                Compare-SemVerVersion -ReferenceVersion $RefVersion -DifferenceVersion $DiffVersion | Should be $ExpectedResult
            }
        }
    }
}
