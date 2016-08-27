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

            It 'Should execute Save-Module' {
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

    Describe "Git Type PS$PSVersion" {

        Context 'Installs Module' {
            Mock Invoke-ExternalCommand {
                [pscustomobject]@{
                    PSB = $PSBoundParameters
                    Arg = $Args
                }
            }
            Mock mkdir { return $true }
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Set-Location {}

            $Dependencies = Get-Dependency @Verbose -Path "$TestDepends\git.depend.psd1"

            It 'Parses the Git dependency type' {
                $Dependencies.count | Should be 3
                ( $Dependencies | Where {$_.DependencyType -eq 'Git'} ).Count | Should Be 3
                ( $Dependencies | Where {$_.DependencyName -like 'nightroman/Invoke-Build'}).Version | Should be 'ac54571010d8ca5107fc8fa1a69278102c9aa077'
                ( $Dependencies | Where {$_.DependencyName -like 'ramblingcookiemonster/PSDeploy'}).Version | Should be 'master'
            }

            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\git.depend.psd1" -Force
            
            It 'Invokes the Git dependency type' {
                Assert-MockCalled -CommandName Invoke-ExternalCommand -Times 6 -Exactly
            }
        }
    }

    Describe "FileDownload Type PS$PSVersion" {

        Context 'Installs Module' {
            Mock Get-WebFile {
                [pscustomobject]@{
                    PSB = $PSBoundParameters
                    Arg = $Args
                }
            }

            $Dependencies = @(Get-Dependency @Verbose -Path "$TestDepends\filedownload.depend.psd1")

            It 'Parses the FileDownload dependency type' {
                $Dependencies.count | Should be 1
                $Dependencies[0].DependencyType | Should be 'FileDownload'
            }

            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\filedownload.depend.psd1" -Force
            
            It 'Invokes the FileDownload dependency type' {
                Assert-MockCalled Get-WebFile -Times 1 -Exactly
            }
        }
    }
}

Remove-Item C:\PSDependPesterTest -Force -Recurse