if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

$null = mkdir 'C:\PSDependPesterTest' -force

InModuleScope 'PSDepend' {

    $TestDepends = Join-Path $ENV:BHProjectPath Tests\DependFiles
    $PSVersion = $PSVersionTable.PSVersion.Major
    $ProjectRoot = $ENV:BHProjectPath
    $SavePath = 'C:\PSDependPesterTest'
    $ExistingPSModulePath = $env:PSModulePath.PSObject.Copy()
    $ExistingPath = $env:Path.PSObject.Copy()

    $Verbose = @{}
    if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose")
    {
        $Verbose.add("Verbose",$True)
    }

    Describe "PSGalleryModule Type PS$PSVersion" {

        Context 'Installs Module' {
            Mock Install-Module { Return $true }
            Mock Get-PSRepository { Return $true }
            
            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.depend.psd1" -Force

            It 'Should execute Install-Module' {
                Assert-MockCalled Install-Module -Times 1 -Exactly
            }

            It 'Should Return Mocked output' {
                $Results | Should be $True
            }
        }

        Context 'Saves Module' {
            Mock Save-Module { Return $true }
            Mock Get-PSRepository { Return $true }
            
            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\savemodule.depend.psd1" -Force

            It 'Should execute Install-Module' {
                Assert-MockCalled Save-Module -Times 1 -Exactly
            }

            It 'Should Return Mocked output' {
                $Results | Should be $True
            }
        }

        Context 'Repository does not Exist' {
            Mock Install-Module {}
            Mock Get-PSRepository { Return $false }

            It 'Throws because Repository could not be found' {
                $Results = { Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.depend.psd1" -Force -ErrorAction Stop }
                $Results | Should Throw
            }
        }

        Context 'Same module version exists' {
            Mock Install-Module {}
            Mock Get-Module {
                [pscustomobject]@{
                    Version = '1.2.5'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{
                    Version = '1.2.5'
                }
            }

            It 'Runs Get-Module and Find-Module, skips Install-Module' {
                $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.sameversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-Module -Times 1 -Exactly
                Assert-MockCalled Find-Module -Times 1 -Exactly
                Assert-MockCalled Install-Module -Times 0 -Exactly
            }
        }

        Context 'Misc' {
            It 'Adds folder to path when specified' {
                Mock Get-PSRepository { Return $true }
                Mock Save-Module {$True}
                $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.addtopath.depend.psd1" -Force -ErrorAction Stop
                $env:PSModulePath -split ";" -contains $SavePath | Should Be $True
                $ENV:PSModulePath = $ExistingPSModulePath
            }
        }
    }
}

Remove-Item C:\PSDependPesterTest -Force -Recurse