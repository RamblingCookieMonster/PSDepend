if(-not $ENV:BHProjectPath)
{
    Set-BuildEnvironment -Path $PSScriptRoot\..
}
Remove-Module $ENV:BHProjectName -ErrorAction SilentlyContinue
Import-Module (Join-Path $ENV:BHProjectPath $ENV:BHProjectName) -Force

$null = mkdir 'C:\PSDependPesterTest' -force

# Maybe use a convention for describe/context/it... these are all over the place...
# Pull requests welcome!

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

        Context 'Imports dependencies' {
            It 'Runs Import-Module when import is specified' {
                Mock Get-PSRepository { Return $true }
                Mock Install-Module {}
                Mock Import-Module
                $Results = Get-Dependency @Verbose -Path "$TestDepends\psgallerymodule.depend.psd1" | Import-Dependency @Verbose
                Assert-MockCalled -CommandName Import-Module -Times 1 -Exactly
                Assert-MockCalled -CommandName Install-Module -Times 0 -Exactly
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
                ( $Dependencies | Where {$_.DependencyName -like '*nightroman/Invoke-Build'}).Version | Should be 'ac54571010d8ca5107fc8fa1a69278102c9aa077'
                ( $Dependencies | Where {$_.DependencyName -like '*ramblingcookiemonster/PSDeploy'}).Version | Should be 'master'
            }

            $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\git.depend.psd1" -Force
            
            It 'Invokes the Git dependency type' {
                Assert-MockCalled -CommandName Invoke-ExternalCommand -Times 6 -Exactly
            }

        }
        Context 'Tests dependency' {
            Mock mkdir { return $true }
            Mock Push-Location
            Mock Pop-Location
            Mock Set-Location
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
    
    Describe "PSGalleryNuget Type PS$PSVersion" {

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
            Mock Find-NugetPackage {
                [pscustomobject]@{
                    Version = '1.2.5'
                }
            }

            It 'Runs Import-LocalizedData and Find-NugetPackage, skips Invoke-ExternalCommand' {
                $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Import-LocalizedData -Times 1 -Exactly
                Assert-MockCalled Find-NugetPackage -Times 1 -Exactly
                Assert-MockCalled Invoke-ExternalCommand -Times 0 -Exactly
            }
        }

        Context 'Tests dependencies' {
            It 'Returns $true when it finds an existing module' {
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
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It "Returns `$false when it doesn't find an existing module" {
                Mock Import-LocalizedData -ParameterFilter {$FileName -eq 'jenkins.psd1'}
                Mock Find-NugetPackage {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerynuget.sameversion.depend.psd1" |
                        Test-Dependency -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }

            It "Returns `$false when it finds an existing module with a lower version" {
                Mock Find-NugetPackage {
                    [pscustomobject]@{
                        Version = '1.2.5'
                    }
                }
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

        Context 'Misc' {
            It 'Adds folder to path when specified' {
                Mock Invoke-ExternalCommand {$True}
                Mock Import-Module 
                $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\psgallerynuget.addtopath.depend.psd1" -Force -ErrorAction Stop
                $env:PSModulePath -split ";" -contains $SavePath | Should Be $True
                $ENV:PSModulePath = $ExistingPSModulePath
            }
        }
    }

    Describe "FileSystem Type PS$PSVersion" {

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
        mkdir $SavePath -Force

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

    Describe "Package Type PS$PSVersion" {
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
            Mock Install-Package
            Mock Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) }
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

            It 'Runs Get-Package and Find-Package, skips Install-Package' {
                $Results = Invoke-PSDepend @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" -Force -ErrorAction Stop

                Assert-MockCalled Get-Package -Times 1 -Exactly
                Assert-MockCalled Find-Package -Times 1 -Exactly
                Assert-MockCalled Install-Package -Times 0 -Exactly
            }
        }

        Context 'Test-Dependency' {
            
            function Get-Package {[cmdletbinding()]param( $ProviderName, $Name, $RequiredVersion)}
            function Install-Package {[cmdletbinding()]param( $Source, $Name, $RequiredVersion)}
            
            It 'Returns $true when it finds an existing module' {
                Mock Install-Package {}
                Mock Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) }
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
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $True
            }

            It "Returns `$false when it doesn't find an existing module" {
                Mock Install-Package {}
                Mock Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) }
                Mock Get-Package { $null }
                Mock Find-Package {
                    [pscustomobject]@{
                        Version = '1.1'
                    }
                }
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\package.sameversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }
            It "Returns `$false when it finds an existing module with a lower version" {
                Mock Install-Package {}
                Mock Get-PackageSource { @([pscustomobject]@{Name = 'chocolatey'; ProviderName = 'chocolatey'}) }
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
                $Results = @( Get-Dependency @Verbose -Path "$TestDepends\psgallerymodule.sameversion.depend.psd1" |
                        Test-Dependency @Verbose -Quiet )
                $Results.Count | Should be 1
                $Results[0] | Should be $False
            }
        }
    }

    Describe "Command Type PS$PSVersion" {

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
}

Remove-Item C:\PSDependPesterTest -Force -Recurse