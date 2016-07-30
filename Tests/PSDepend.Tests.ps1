$PSVersion = $PSVersionTable.PSVersion.Major
$ModuleName = $ENV:BHProjectName

# Verbose output for non-master builds on appveyor
# Handy for troubleshooting.
# Splat @Verbose against commands as needed (here or in pester tests)
    $Verbose = @{}
    if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose")
    {
        $Verbose.add("Verbose",$True)
    }

Import-Module $PSScriptRoot\..\$ModuleName -Force

Describe "$ModuleName PS$PSVersion" {
    Context 'Strict mode' {

        Set-StrictMode -Version latest

        It 'Should load' {
            $Module = Get-Module $ModuleName
            $Module.Name | Should be $ModuleName
        }
    }
}
