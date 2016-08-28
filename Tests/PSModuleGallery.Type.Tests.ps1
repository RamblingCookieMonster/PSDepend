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

        Context 'Installs Modules' {
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

        Context 'Saves Modules' {
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

        Context 'Test-Dependency' {
            It 'Returns $true when it finds an existing module' {
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
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It "Returns `$false when it doesn't find an existing module" {
                Mock Install-Module {}
                Mock Get-Module { $null }
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }
            It "Returns `$false when it finds an existing module with a lower version" {
                Mock Install-Module {}
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.4'
                    }
                }
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
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
            } -ParameterFilter {$Arguments -contains 'checkout' -or $Arguments -contains 'clone'}
            Mock mkdir { return $true }
            Mock Push-Location
            Mock Pop-Location
            Mock Set-Location
            Mock Test-Path { return $False } -ParameterFilter {$Path -match "Invoke-Build$|PSDeploy$"}

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

        Context 'Installs dependency' {
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

            New-Item -ItemType File -Path (Join-Path $SavePath 'System.Data.SQLite.dll')
            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\filedownload.depend.psd1" -Force

            It 'Parses URL file name and skips on existing' {
                Assert-MockCalled Get-WebFile -Times 1 -Exactly # already called, so still 1, not 2...
            }
        }

        Remove-Item $SavePath -Force -Recurse
        mkdir $SavePath -Force

        Context 'Tests dependency' {
            It 'Returns $false if file does not exist' {
                Mock Get-WebFile {}
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filedownload.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should be 1
                $Results[0] | Should be $False
                Assert-MockCalled -CommandName Get-WebFile -Times 0 -Exactly
            }

            New-Item -ItemType File -Path (Join-Path $SavePath 'System.Data.SQLite.dll')
            It 'Returns $true if file does exist' {
                Mock Get-WebFile {}
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filedownload.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should be 1
                $Results[0] | Should be $true
                Assert-MockCalled -CommandName Get-WebFile -Times 0 -Exactly
            }
        }
    }
}

Remove-Item C:\PSDependPesterTest -Force -Recurse