if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path "$PSScriptRoot/.."
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

# Maybe use a convention for describe/context/it... these are all over the place...
# Pull requests welcome!

InModuleScope 'PSDepend' {

    $TestDepends = Join-Path $ENV:BHProjectPath "Tests/DependFiles"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $ProjectRoot = $ENV:BHProjectPath
    $ExistingPSModulePath = $env:PSModulePath.PSObject.Copy()
    $ExistingPath = $env:PATH.PSObject.Copy()

    $Password = 'testPassword' | ConvertTo-SecureString -AsPlainText -Force
    $TestCredential = New-Object System.Management.Automation.PSCredential('testUser', $Password)
    $OtherCredential = New-Object System.Management.Automation.PSCredential('otherUser', $Password)
    $Credentials = @{
        'imaginaryCreds' = $TestCredential
        'otherCreds' = $OtherCredential
    }

    $Verbose = @{}
    if($ENV:BHBranchName -notlike "master" -or $env:BHCommitMessage -match "!verbose")
    {
        $Verbose.add("Verbose",$True)
    }

    Describe "PSGalleryModule Type PS$PSVersion" {

        $SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

        Context 'Installs Modules' {
            Mock Install-Module { Return $true }

            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.depend.psd1" -Force

            It 'Should execute Install-Module' {
                Assert-MockCalled Install-Module -Times 1 -Exactly
            }

            It 'Should Return Mocked output' {
                $Results | Should be $True
            }
		}

		Context 'Installs Modules with credentials' {
			Mock Install-Module { Return $true }

			 $Results = Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.withcredentials.depend.psd1" -Force -Credentials $Credentials

			 It 'Should execute Install-Module' {
				Assert-MockCalled Install-Module -Times 1 -Exactly -ParameterFilter { $Credential -ne $null -and $Credential.Username -eq 'testUser' }
			}

			 It 'Should Return Mocked output' {
				$Results | Should be $True
			}
		}

		Context 'Installs Modules with multiple credentials' {
			Mock Install-Module { Return $true }

			 $Results = Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.multiplecredentials.depend.psd1" -Force -Credentials $Credentials

			 It 'Should execute Install-Module with the correct credentials' {
				Assert-MockCalled Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'imaginary' -and $Credential -ne $null -and $Credential.Username -eq 'testUser' }
				Assert-MockCalled Install-Module -Times 1 -Exactly -ParameterFilter { $Name -eq 'other' -and $Credential -ne $null -and $Credential.Username -eq 'otherUser' }
			}

			 It 'Should Return Mocked output' {
				$Results | Should be @($True, $True)
			}
		}

        Context 'Saves Modules' {
            Mock Save-Module { Return $true }

            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends/savemodule.depend.psd1" -Force

            It 'Should execute Save-Module' {
                Assert-MockCalled Save-Module -Times 1 -Exactly
            }

            It 'Should Return Mocked output' {
                $Results | Should be $True
            }
        }

		Context 'Saves Modules with credentials' {
			Mock Save-Module { Return $true }

			 $Results = Invoke-PSDepend @Verbose -Path "$TestDepends/savemodule.withcredentials.depend.psd1" -Force -Credentials $Credentials

			 It 'Should execute Save-Module' {
				Assert-MockCalled Save-Module -Times 1 -Exactly -ParameterFilter { $Credential -ne $null -and $Credential.Username -eq 'testUser' }
			}

			 It 'Should Return Mocked output' {
				$Results | Should be $True
			}
		}

        Context 'Repository does not Exist' {
            Mock Install-Module { throw "Unable to find repository 'Blah'" } -ParameterFilter { $Repository -eq 'Blah'}

            It 'Throws because Repository could not be found' {
                $Results = { Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.missingrepo.depend.psd1" -Force -ErrorAction Stop }
                $Results | Should Throw
            }
        }

        Context 'Same module version exists (Version)' {
            Mock Install-Module {}
            Mock Get-Module {
                [pscustomobject]@{
                    Version = '1.2.5'
                }
            }
            Mock Find-Module

            It 'Skips Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.sameversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-Module -Times 1 -Exactly
                Assert-MockCalled Find-Module -Times 0 -Exactly
                Assert-MockCalled Install-Module -Times 0 -Exactly
            }
        }

        Context 'Same module version exists (SemVersion)' {
            Mock Install-Module {}
            Mock Get-Module {
                [pscustomobject]@{
                    Version = '1.2.5-preview0002'
                }
            }
            Mock Find-Module

            It 'Skips Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-Module -Times 1 -Exactly
                Assert-MockCalled Find-Module -Times 0 -Exactly
                Assert-MockCalled Install-Module -Times 0 -Exactly
            }
        }

        Context 'Latest module required, and already installed (version)' {
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

            It 'Skips Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-Module -Times 1 -Exactly
                Assert-MockCalled Find-Module -Times 1 -Exactly
                Assert-MockCalled Install-Module -Times 0 -Exactly
            }
        }

        Context 'Latest module required, and already installed (SemVersion)' {
            Mock Install-Module {}
            Mock Get-Module {
                [pscustomobject]@{
                    Version = '1.2.5-preview0002'
                }
            }
            Mock Find-Module {
                [pscustomobject]@{
                    Version = '1.2.5-preview0002'
                }
            }

            It 'Skips Install-Module' {
                Invoke-PSDepend @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-Module -Times 1 -Exactly
                Assert-MockCalled Find-Module -Times 1 -Exactly
                Assert-MockCalled Install-Module -Times 0 -Exactly
            }
        }

        Context 'Test-Dependency' {

            BeforeEach {
                Mock Install-Module {}
                Mock Find-Module {}
            }

            It 'Returns $true when it finds an existing module (Version)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It 'Returns $true when it finds an existing module (SemVersion)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It 'Returns $true when it finds an existing latest module (Version)' {
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
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It 'Returns $true when it finds an existing latest module (SemVersion)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                }
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It "Returns `$false when it doesn't find an existing module (Version)" {
                Mock Get-Module { $null }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It "Returns `$false when it doesn't find an existing module (SemVersion)" {
                Mock Get-Module { $null }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It "Returns `$false when it finds an existing module with a lower version (Version)" {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.4'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It 'Returns $false when it finds an existing module with a lower version (SemVersion)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0001'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It 'Returns $false when it finds an existing module with a lower version (SemVersion-Version)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.4'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.SameSemanticVersion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It 'Returns $false when it finds an existing module with a lower version than latest (Version)' {
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
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It 'Returns $false when it finds an existing module with a lower version than latest (SemVersion)' {
                Mock Get-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0001'
                    }
                }
                Mock Find-Module {
                    [pscustomobject]@{
                        Version = '1.2.5-preview0002'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }
        }

        Context 'Imports dependencies' {
            It 'Runs Import-Module when import is specified' {
                Mock Install-Module {}
                Mock Import-Module
                $Results = Get-Dependency @Verbose -Path "$TestDepends/psgallerymodule.depend.psd1" | Import-Dependency @Verbose
                Assert-MockCalled -CommandName Import-Module -Times 1 -Exactly
                Assert-MockCalled -CommandName Install-Module -Times 0 -Exactly
            }
        }

        Context 'AddToPath on install of module to target folder' {
            It 'Adds folder to path' {
                Mock Save-Module {$True}
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.addtopath.depend.psd1" -Force -ErrorAction Stop
                ($env:PSModulePath -split ([IO.Path]::PathSeparator)) -contains $SavePath | Should Be $True
                $ENV:PSModulePath = $ExistingPSModulePath
            }
        }

        Context 'AddToPath on import of module in target folder' {

            $addToPathTestCases = @(
                @{
                    Version = 'specific version'
                    DependPsd1File = "psgallerymodule.addtopath.depend.psd1"
                },
                @{
                    Version = 'latest version'
                    DependPsd1File = "psgallerymodule.latestaddtopath.depend.psd1"
                }
            )

            Mock Install-Module
            Mock Import-Module
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

            AfterEach {
                $ENV:PSModulePath = $ExistingPSModulePath
            }

            It 'adds folder to path for <Version>' -TestCases $addToPathTestCases {
                param($DependPsd1File)

                # when
                Invoke-PSDepend @Verbose -Path "$TestDepends\$DependPsd1File" -Import -Force -ErrorAction Stop

                # check assumption that expected code path was followed...
                Assert-MockCalled Install-Module -Times 0 -Exactly -Scope It
                Assert-MockCalled Import-Module -Times 1 -Exactly -Scope It

                # then
                ($env:PSModulePath -split ([IO.Path]::PathSeparator)) -contains $SavePath | Should Be $True
            }
        }
#>
        Context 'SkipPublisherCheck' {
            It 'Supplies SkipPublisherCheck switch to Install-Module' {
                Mock Get-PSRepository { Return $true }
                Mock Install-Module {}
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.skippubcheck.depend.psd1" -Force -ErrorAction Stop
                Assert-MockCalled -CommandName Install-Module -Times 1 -Exactly -ExclusiveFilter {
                    $SkipPublisherCheck -eq $true
                }
            }
        }

        Context 'AllowPrerelease' {
            It 'Supplies AllowPrerelease switch to Install-Module' {
                Mock Get-PSRepository { Return $true }
                Mock Install-Module {}
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerymodule.AllowPrerelease.depend.psd1" -Force -ErrorAction Stop
                Assert-MockCalled -CommandName Install-Module -Times 1 -Exactly -ExclusiveFilter {
                    $AllowPrerelease -eq $true
                }
            }
        }
    }

    Describe "Git Type PS$PSVersion"  -Tag "WindowsOnly" {

        $SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

        Context 'Installs Module' {
            Mock Invoke-ExternalCommand {
                [pscustomobject]@{
                    PSB = $PSBoundParameters
                    Arg = $Args
                }
            } -ParameterFilter {$Arguments -contains 'checkout' -or $Arguments -contains 'clone'}
            Mock New-Item { return $true }
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Set-Location {}
            Mock Test-Path { return $False } -ParameterFilter {$Path -match "Invoke-Build$|PSDeploy$"}

            $Dependencies = Get-Dependency @Verbose -Path "$TestDepends\git.depend.psd1"

            It 'Parses the Git dependency type' {
                $Dependencies.count | Should be 3
                ( $Dependencies | Where {$_.DependencyType -eq 'Git'} ).Count | Should Be 3
                ( $Dependencies | Where {$_.DependencyName -like '*nightroman/Invoke-Build'}).Version | Should be 'ac54571010d8ca5107fc8fa1a69278102c9aa077'
                ( $Dependencies | Where {$_.DependencyName -like '*ramblingcookiemonster/PSDeploy'}).Version | Should be 'master'
            }

            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\git.depend.psd1" -Force

            It 'Invokes the Git dependency type' {
                Assert-MockCalled -CommandName Invoke-ExternalCommand -Times 6 -Exactly
            }

        }

        Context 'Tests dependency' {
            Mock New-Item { return $true }
            Mock Push-Location {}
            Mock Pop-Location {}
            Mock Set-Location {}
            Mock Invoke-ExternalCommand -ParameterFilter {$Arguments -contains 'checkout' -or $Arguments -contains 'clone'}


            It 'Returns $false if git repo does not exist' {
                Mock Test-Path { return $False } -ParameterFilter {$Path -match "PSDeploy$"}
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\git.test.depend.psd1" | Test-Dependency @Verbose -Quiet )
                $Results.count | Should be 1
                $Results[0] | Should be $False
            }

            It 'Returns $true if git repo does exist' {
                Mock Test-Path { return $true } -ParameterFilter {$Path -match "PSDeploy$"}
                Mock Invoke-ExternalCommand { return 'imaginary_branch' } -ParameterFilter {$Arguments -contains 'rev-parse'}
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\git.test.depend.psd1" | Test-Dependency @Verbose -Quiet )
                $Results.count | Should be 1
                $Results[0] | Should be $true
            }
        }
    }

    Describe "FileDownload Type PS$PSVersion" -Tag "WindowsOnly" {

        $SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

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
        $null = New-Item $SavePath -ItemType Directory -Force

        Context 'Tests dependency' {
            It 'Returns $false if file does not exist' {
                Mock Get-WebFile {}
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filedownload.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should be 1
                $Results[0] | Should be $False
                Assert-MockCalled -CommandName Get-WebFile -Times 0 -Exactly
            }

            New-Item -ItemType File -Path (Join-Path $SavePath 'System.Data.SQLite.dll') -Force
            It 'Returns $true if file does exist' {
                Mock Get-WebFile {}
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filedownload.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should be 1
                $Results[0] | Should be $true
                Assert-MockCalled -CommandName Get-WebFile -Times 0 -Exactly
            }
        }
    }

    Describe "PSGalleryNuget Type PS$PSVersion" -Tag "WindowsOnly" {

        $SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

        Context 'Installs Modules' {
            Mock Test-Path { Return $true } -ParameterFilter { $PathType -eq 'Container' }
            Mock Invoke-ExternalCommand { Return $true }
            Mock Find-NugetPackage { Return $true }

            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.depend.psd1" -Force

            It 'Should execute Invoke-ExternalCommand' {
                Assert-MockCalled Invoke-ExternalCommand -Times 1 -Exactly
            }

            It 'Should Return Mocked output' {
                $Results | Should be $True
            }
        }

        Context 'Same module version exists' {
            Mock Test-Path {return $True} -ParameterFilter {$Path -match 'jenkins'}
            Mock Invoke-ExternalCommand {}
            Mock Import-LocalizedData {
                [pscustomobject]@{
                    ModuleVersion = '1.2.5'
                }
            } -ParameterFilter {$FileName -eq 'jenkins.psd1'}
            Mock Find-NugetPackage

            It 'Skips Invoke-ExternalCommand' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Import-LocalizedData -Times 1 -Exactly
                Assert-MockCalled Find-NugetPackage -Times 0 -Exactly
                Assert-MockCalled Invoke-ExternalCommand -Times 0 -Exactly
            }
        }

        Context 'Latest module required, and already installed' {
            Mock Test-Path {return $True} -ParameterFilter {$Path -match 'jenkins'}
            Mock Invoke-ExternalCommand {}
            Mock Import-LocalizedData {
                [pscustomobject]@{
                    ModuleVersion = '1.2.5'
                }
            } -ParameterFilter {$FileName -eq 'jenkins.psd1'}
            Mock Find-NugetPackage {
                [pscustomobject]@{
                    Version = '1.2.5'
                }
            }

            It 'Skips Invoke-ExternalCommand' {
                Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.latestversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Import-LocalizedData -Times 1 -Exactly
                Assert-MockCalled Find-NugetPackage -Times 1 -Exactly
                Assert-MockCalled Invoke-ExternalCommand -Times 0 -Exactly
            }
        }

        Context 'Tests dependencies' {

            BeforeEach {
                Mock Invoke-ExternalCommand {}
                Mock Test-Path {return $True} -ParameterFilter {$Path -match 'jenkins'}
                Mock Find-NugetPackage {}
            }

            It 'Returns $true when it finds an existing module' {
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.5'
                    }
                } -ParameterFilter {$FileName -eq 'jenkins.psd1'}
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It 'Returns $true when it finds an existing latest module' {
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.5'
                    }
                } -ParameterFilter {$FileName -eq 'jenkins.psd1'}
                Mock Find-NugetPackage {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It "Returns `$false when it doesn't find an existing module" {
                Mock Import-LocalizedData -ParameterFilter {$FileName -eq 'jenkins.psd1'}
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It "Returns `$false when it finds an existing module with a lower version" {
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.4'
                    }
                } -ParameterFilter {$FileName -eq 'jenkins.psd1'}

                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It "Returns `$false when it finds an existing module with a lower version than latest" {
                Mock Import-LocalizedData {
                    [pscustomobject]@{
                        ModuleVersion = '1.2.4'
                    }
                } -ParameterFilter {$FileName -eq 'jenkins.psd1'}
                Mock Find-NugetPackage {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                }

                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.latestversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }
        }

        Context 'Imports dependencies' {
            It 'Runs Import-Module when import is specified' {
                Mock Invoke-ExternalCommand {$True}
                Mock Import-Module
                $Results = Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.depend.psd1" | Import-Dependency @Verbose
                Assert-MockCalled -CommandName Import-Module -Times 1 -Exactly
                Assert-MockCalled -CommandName Invoke-ExternalCommand -Times 0 -Exactly
            }
        }

        Context 'AddToPath on install of module to target folder' {
            It 'Adds folder to path' {
                Mock Invoke-ExternalCommand {$True}
                Mock Import-Module
                $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.addtopath.depend.psd1" -Force -ErrorAction Stop
                $env:PSModulePath -split ([IO.Path]::PathSeparator) -contains $SavePath | Should Be $True
                $ENV:PSModulePath = $ExistingPSModulePath
            }
        }


        Context 'AddToPath on import of module in target folder' {

            $addToPathTestCases = @(
                @{
                    Version = 'specific version'
                    DependPsd1File = "psgallerynuget.addtopath.depend.psd1"
                },
                @{
                    Version = 'latest version'
                    DependPsd1File = "psgallerynuget.latestaddtopath.depend.psd1"
                }
            )

            Mock Test-Path {return $True} -ParameterFilter {$Path -match 'imaginary'}
            Mock Invoke-ExternalCommand {}
            Mock Import-Module
            Mock Import-LocalizedData {
                [pscustomobject]@{
                    ModuleVersion = '1.2.5'
                }
            } -ParameterFilter {$FileName -eq 'imaginary.psd1'}
            Mock Find-NugetPackage {
                [pscustomobject]@{
                    Version = '1.2.5'
                }
            }

            AfterEach {
                $ENV:PSModulePath = $ExistingPSModulePath
            }

            It 'adds folder to path for <Version>' -TestCases $addToPathTestCases {
                param($DependPsd1File)

                # when
                Invoke-PSDepend @Verbose -Path "$TestDepends\$DependPsd1File" -Import -Force -ErrorAction Stop

                # check assumption that expected code path was followed...
                Assert-MockCalled Invoke-ExternalCommand -Times 0 -Exactly -Scope It
                Assert-MockCalled Import-Module  -Times 1 -Exactly -Scope It

                # then
                (($env:PSModulePath -split ([IO.Path]::PathSeparator))) -contains $SavePath | Should Be $True
            }
        }
    }

    Describe "FileSystem Type PS$PSVersion" -Tag "WindowsOnly" {

        $SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

        Context 'Installs dependency' {
            Mock Copy-Item

            $Dependencies = @(Get-Dependency @Verbose -Path "$TestDepends\filesystem.depend.psd1")

            It 'Parses the FileDownload dependency type' {
                $Dependencies.count | Should be 1
                $Dependencies[0].DependencyType | Should be 'FileSystem'
            }

            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\filesystem.depend.psd1" -Force

            It 'Invokes the FileSystem dependency type' {
                Assert-MockCalled Copy-Item -Times 1 -Exactly
            }

            New-Item -ItemType File -Path (Join-Path $SavePath 'notepad.exe')
            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\filesystem.depend.psd1" -Force

            It 'Still copies if file hashes do not match' {
                Assert-MockCalled Copy-Item -Times 2 -Exactly # already called, so 2...
            }
        }

        Remove-Item $SavePath -Force -Recurse
        $null = New-Item $SavePath -ItemType Directory -Force

        Context 'Tests dependency' {
            It 'Returns $false if file does not exist' {
                Mock Copy-Item
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filesystem.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should be 1
                $Results[0] | Should be $False
                Assert-MockCalled -CommandName Copy-Item -Times 0 -Exactly
            }

            xcopy C:\Windows\notepad.exe $(Join-Path $SavePath '*') /Y

            It 'Returns $true if file does exist' {
                Mock Copy-Item
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\filesystem.depend.psd1" | Test-Dependency @Verbose -Quiet)
                $Results.count | Should be 1
                $Results[0] | Should be $true
                Assert-MockCalled -CommandName Copy-Item -Times 0 -Exactly
            }
        }
    }

    Describe "Package Type PS$PSVersion" -tag pkg {

        $SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

        # So... these didn't work with mocking.  Create function, define alias to override any function call, mock that.
        function Get-Package {[cmdletbinding()]param( $ProviderName, $Name, $RequiredVersion)}
        function Install-Package {[cmdletbinding()]param( $Source, $Name, $RequiredVersion)}

        <# Works, but waiting on https://github.com/pester/Pester/issues/604...
         # Got past Get-Package, but Install-Package is still giving the parameter error
        Context 'Installs Packages' {
            Mock Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) }
            Mock Get-Package
            Mock Install-Package { $True }

            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\package.depend.psd1" -Force

            It 'Should execute Install-Package' {
                Assert-MockCalled Install-Package -Times 1 -Exactly
            }

            It 'Should Return Mocked output' {
                $Results | Should be $True
            }
        }
        #>
        Context 'PackageSource does not Exist' {
            Mock Install-Package
            Mock Get-PackageSource

            It 'Throws because Repository could not be found' {
                $Results = { Invoke-PSDepend @Verbose -Path "$TestDepends\package.depend.psd1" -Force -ErrorAction Stop }
                $Results | Should Throw
            }
        }

        Context 'Same package version exists' {

            function Install-Package {[cmdletbinding()]param( $Source, $Name, $RequiredVersion, $Force)}
            function Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) }

            It 'Skips Install-Package' {

                Mock Install-Package
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                }
                Mock Find-Package

                Invoke-PSDepend @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-Package -Times 1 -Exactly
                Assert-MockCalled Find-Package -Times 0 -Exactly
                Assert-MockCalled Install-Package -Times 0 -Exactly
            }
        }

        Context 'Latest package required, and already installed' {

            <#
                This test works on my machine but not in AppVeyor (!)
                The test DOES work in AppVeyor but only if the previous test above is skipped (!!)

                I think this is a problem can be isolated to something to do with Pester Mocks.

                AppVeyor failure:

                "Parameter set cannot be resolved using the specified named parameters.
                at line: 188 in C:\projects\psdepend\psdepend\Public\Invoke-DependencyScript.ps1"

                See build logs: https://ci.appveyor.com/project/RamblingCookieMonster/psdepend/build/1.0.124

            #>

            function Install-Package {[cmdletbinding()]param( $Source, $Name, $RequiredVersion, $Force)}
            function Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) }

            It 'Runs Get-Package and Find-Package, skips Install-Package' -Skip {

                Mock Install-Package
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                }
                Mock Find-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                }

                Invoke-PSDepend @Verbose -Path "$TestDepends\package.latestversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-Package -Times 1 -Exactly
                Assert-MockCalled Find-Package -Times 1 -Exactly
                Assert-MockCalled Install-Package -Times 0 -Exactly
            }
        }

        Context 'Test-Dependency' {

            if (-not (Get-Command Get-Package -Module PackageManagement)) {
            function Get-Package {[cmdletbinding()]param( $ProviderName, $Name, $RequiredVersion) write-verbose "WTF NOW"}
            }
            if (-not (Get-Command Install-Package -Module PackageManagement)) {
            function Install-Package {[cmdletbinding()]param( $Source, $Name, $RequiredVersion, $Force)}
            }
            function Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) }

            BeforeEach {
                Mock Install-Package {}
                Mock Find-Package {}
            }

            It 'Returns $true when it finds an existing module' {
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It 'Returns $true when it finds an existing latest module' {
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                }
                Mock Find-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.latestversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It "Returns `$false when it doesn't find an existing module" {
                Mock Get-Package { $null }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It "Returns `$false when it finds an existing module with a lower version" {
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.0'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It "Returns `$false when it finds an existing module with a lower version than latest" {
                Mock Get-Package {
                    [pscustomobject]@{
                        Version = '1.0'
                    }
                }
                Mock Find-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.latestversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }
        }
    }

    Describe "Command Type PS$PSVersion" {

        $SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

        Context 'Invokes a command' {

            $Dependencies = @(Get-Dependency @Verbose -Path "$TestDepends\command.depend.psd1")

            It 'Parses the command dependency type' {
                $Dependencies.count | Should be 1
                $Dependencies[0].DependencyType | Should be 'Command'
            }

            It 'Invokes a command' {
                $Output = Invoke-PSDepend @Verbose -Path "$TestDepends\command.depend.psd1" -Force
                $Output | Should be 'hello world'
            }
        }
    }

    Describe "Npm Type PS$PSVersion" {

        $SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

        Context 'Installs Dependency' {
            Mock Get-NodeModule {return $null}
            Mock Install-NodeModule {}
            Mock New-Item {return true}
            Mock Push-Location
            Mock Pop-Location

            $Dependencies = Get-Dependency @Verbose -Path "$TestDepends\npm.depend.psd1"
            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\npm.depend.psd1" -Force

            It 'Parses the Npm dependency type' {
                $Dependencies.count | Should be 2
                ( $Dependencies | Where-Object {$_.DependencyType -eq 'Npm'} ).Count | Should Be 2
                ( $Dependencies | Where-Object {$_.DependencyName -like 'gitbook-cli'}).Version | Should be '2.3.0'
                ( $Dependencies | Where-Object {$_.DependencyName -like 'gitbook-cli'}).Target | Should be 'Global'
                ( $Dependencies | Where-Object {$_.DependencyName -like 'gitbook-summary'}).Version | Should BeNullOrEmpty
            }

            It 'Invokes the Nppm dependency type' {
                Assert-MockCalled -CommandName Install-NodeModule -Times 2 -Exactly
            }
        }

        Context 'Tests Dependency' {
            Mock Install-NodeModule {}
            Mock New-Item {return true}
            Mock Push-Location
            Mock Pop-Location

            $Dependencies = Get-Dependency @Verbose -Path "$TestDepends\npm.depend.psd1"

            It 'Returns $false if the module is not installed' {
                Mock Get-NodeModule {return $null}
                Invoke-PSDepend @Verbose -Path "$TestDepends\npm.depend.psd1" -Test -Quiet | Should Be $false
            }

            It 'Returns $true if the module is installed' {
                Mock Get-NodeModule {return [pscustomobject]@{
                    'gitbook-cli' = @{
                        version = '2.3.0'
                    }
                }} -ParameterFilter {$Target -eq 'Global'}
                Mock Get-NodeModule {return [pscustomobject]@{
                    'gitbook-summary' = @{
                        version = '1.2.3'
                    }
                }}
                Invoke-PSDepend @Verbose -Path "$TestDepends\npm.depend.psd1" -Test -Quiet | Should Be $true
            }
        }
    }

    Describe "DotnetSdk Type PS$PSVersion" {
        $IsWindowsEnv = !$PSVersionTable.Platform -or $PSVersionTable.Platform -eq "Win32NT"
        $GlobalDotnetSdkLocation = if ($IsWindowsEnv) { "$env:LocalAppData\Microsoft\dotnet" } else { "$env:HOME/.dotnet" }
        $DotnetFile = if ($IsWindowsEnv) { "dotnet.exe" } else { "dotnet" }
        $SavePath = '.dotnet'

        Context 'Installs Dependency' {
            $Dependency = Get-Dependency @Verbose -Path "$TestDepends\dotnetsdk.complex.depend.psd1"
            It 'Parses the DotnetSdk dependency type' {
                $Dependency | Should -Not -BeNullOrEmpty
                $Dependency.DependencyType | Should -Be 'DotnetSdk'
                $Dependency.Version | Should -Be '2.1.300'
                $Dependency.DependencyName | Should -Be 'release'
                $Dependency.Target | Should -Be $SavePath
            }

            It 'Installs the .NET Core SDK to the specified directory' {
                Mock Test-Dotnet { return $false }

                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.complex.depend.psd1" -Force
                Test-Path $SavePath | Should -BeTrue
            }

            It 'Does nothing if the .NET Core SDK is found' {
                Mock Test-Dotnet { return $true }
                Mock Install-Dotnet

                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.complex.depend.psd1" -Force
                Assert-MockCalled -CommandName Install-Dotnet -Times 0 -Exactly
            }

            AfterAll {
                Remove-Item -Force -Recurse $SavePath -ErrorAction SilentlyContinue
            }
        }

        Context 'Tests Dependency' {
            # used to see if 'dotnet' is already on the PATH - we need this to return false
            Mock Get-Command { return $false } -ParameterFilter { $Name -eq 'dotnet' }
            Mock Test-Path { return $true } -ParameterFilter  { $Path -eq (Join-Path $GlobalDotnetSdkLocation $DotnetFile) }
            Mock Get-DotnetVersion { return '2.1.330-rc1' }

            It 'Can propertly compare semantic versions' {
                # '2.1.330-rc1' >= '2.1.330-preview1'
                # '2.1.330-rc1' >= '2.1.330-rc1'
                # '2.1.330-rc1' >= '1.0'
                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.semanticversion.depend.psd1" -Test -Quiet | Should -BeTrue
            }
        }

        Context 'Imports Dependency' {
            # used to see if 'dotnet' is already on the PATH - we need this to return false
            Mock Get-Command { return $false } -ParameterFilter { $Name -eq 'dotnet' }

            BeforeAll {
                $originalPath = $env:PATH
            }

            It 'Can add the Target of the .NET Core SDK to the PATH' {
                Mock Test-Dotnet { return $true }
                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.complex.depend.psd1" -Force -Import -ErrorAction Stop

                ($env:PATH -split [IO.Path]::PathSeparator)[0] | Should -Be $SavePath
            }
            It 'Can add the global path of the .NET Core SDK to the PATH' {
                Mock Test-Dotnet { return $true }
                Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.simple.depend.psd1" -Force -Import -ErrorAction Stop

                ($env:PATH -split [IO.Path]::PathSeparator)[0] | Should -Be $GlobalDotnetSdkLocation
            }
            It 'Throws if the path cannot be found' {
                Mock Test-Dotnet { return $false }
                { Invoke-PSDepend @Verbose -Path "$TestDepends\dotnetsdk.simple.depend.psd1" -Force -Import -ErrorAction Stop } |
                    Should -Throw -ExpectedMessage ".NET SDK cannot be located. Try installing using PSDepend."
            }
            AfterEach {
                $env:PATH = $originalPath
            }
        }
    }

    Describe "Chocolatey Type PS$PSVersion" -Tag 'Chocolatey', "WindowsOnly" {

        $SavePath = (New-Item 'TestDrive:/PSDependPesterTest' -ItemType Directory -Force).FullName

        # So... these didn't work with mocking.  Create function, define alias to override any function call, mock that.
        function Invoke-ChocoInstallPackage
        {
            [cmdletbinding()]param($Name, $Version, $Source, $Force, $Credential)
        }
        function Get-ChocoLatestPackage
        {
            [cmdletbinding()]param( $Source, $Name, $RequiredVersion)
        }

        function Get-ChocoInstalledPackage
        {
            [cmdletbinding()]param($Name)
        }

        Context 'Chocolatey is not installed' {

            It 'installs Chocolatey' {
                Mock Get-Command -ParameterFilter { $Name -eq 'choco.exe' } -MockWith { return $false }
                Mock Invoke-WebRequest

                # this will throw as the source is invalid - lets catch that
                { Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.specificversionrequested.depend.psd1" -Force -ErrorAction Stop } | Should -Throw

                Assert-MockCalled Get-Command -Times 1 -Exactly
                Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
            }
        }

        Context 'Source does not exist' {

            It 'Does not throw if the Source cannot be found' {
                { Invoke-PSDepend -Path "$TestDepends\chocolatey.dummysource.depend.psd1" -Force -ErrorAction Stop } | Should -Not -Throw
            }
        }

        Context 'Package version installed is what is requested' {

            It 'skips installing the package' {

                Mock Get-ChocoInstalledPackage { @{ Name = $Name; Version = '1.0' } }
                Mock Get-ChocoLatestPackage
                Mock Invoke-ChocoInstallPackage

                Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.specificversionrequested.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-ChocoInstalledPackage -Times 1 -Exactly
                Assert-MockCalled Get-ChocoLatestPackage -Times 0 -Exactly
                Assert-MockCalled Invoke-ChocoInstallPackage -Times 0 -Exactly
            }
        }

        Context 'Package version installed is latest' {

            It 'skips installing the package' {

                Mock Get-ChocoInstalledPackage { @{ Name = $Name; Version = '2.0' } }
                Mock Get-ChocoLatestPackage { @{ Name = $Name; Version = '2.0' } }
                Mock Invoke-ChocoInstallPackage

                Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.latestversionrequested.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-ChocoInstalledPackage -Times 1 -Exactly
                Assert-MockCalled Get-ChocoLatestPackage -Times 1 -Exactly
                Assert-MockCalled Invoke-ChocoInstallPackage -Times 0 -Exactly
            }
        }

        Context 'Package requested is latest and version installed is newer than available in source' {

            It 'skips installing the package' {

                Mock Get-ChocoInstalledPackage { @{ Name = $Name; Version = '2.0' } }
                Mock Get-ChocoLatestPackage { @{ Name = $Name; Version = '1.0' } }
                Mock Invoke-ChocoInstallPackage

                Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.latestversionrequested.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-ChocoInstalledPackage -Times 1 -Exactly
                Assert-MockCalled Get-ChocoLatestPackage -Times 1 -Exactly
                Assert-MockCalled Invoke-ChocoInstallPackage -Times 0 -Exactly
            }
        }

        Context 'Package requested is latest and version installed is older than available in source' {

            It 'installs the package' {

                Mock Get-ChocoInstalledPackage { @{ Name = $Name; Version = '1.0' } }
                Mock Get-ChocoLatestPackage { @{ Name = $Name; Version = '2.0' } }
                Mock Invoke-ChocoInstallPackage

                Invoke-PSDepend @Verbose -Path "$TestDepends\chocolatey.latestversionrequested.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-ChocoInstalledPackage -Times 1 -Exactly
                Assert-MockCalled Get-ChocoLatestPackage -Times 1 -Exactly
                Assert-MockCalled Invoke-ChocoInstallPackage -Times 1 -Exactly
            }
        }
    }
}
