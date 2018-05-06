# Handling Module Dependencies

The PowerShellGet functions are pretty cool - if you run `Install-Module XYZ`, you'll get XYZ, and any modules defined in XYZ's `RequiredModules` manifest section.  But... What if the gallery isn't your only dependency source? 

This is a quick demo illustrating a quick way to pull down module dependencies.  You might run this during an automated build, or even at run time given that this should be idempotent.

## Set Up the Demo Module

We'll set up a demo module in C:\MyModule.

```powershell
# Set up a new module.  We'll create a basic skeleton that does nothing.
mkdir C:\MyModule -force
New-ModuleManifest -Path C:\MyModule\MyModule.psd1 `
                   -RootModule 'MyModule.psm1' `
                   -FunctionsToExport Test-PSDependExample `
                   -CmdletsToExport $null `
                   -VariablesToExport $null `
                   -AliasesToExport $null
                   
Set-Content -Path C:\MyModule\MyModule.psm1 @'
# Load up dependencies!
Invoke-PSDepend -Path $PSScriptRoot\requirements.psd1 -Target $PSScriptRoot\Dependencies -Install -Force

Import-Module Posh-SSH
Function Test-PSDependExample {
    Get-ChildItem $PSScriptRoot\Dependencies -Recurse -Depth 1 | Select -ExpandProperty FullName
    Get-Module | Select Name, Path
}
'@

Set-Content C:\MyModule\Requirements.psd1 -Value @'
@{
    PSDependOptions = @{
        Target = '$DependencyFolder\Dependencies'
        Parameters = @{
            Force = $True
        }
    }

    # Grab some modules
    'Posh-SSH' = 'latest'

    # Clone a repo
    'ramblingcookiemonster/PowerShell' = 'master'

    # Download a file
    'AzCopy_Download' = @{
        Name = 'azcopy.msi'
        DependencyType = 'FileDownload'
        Source = 'http://aka.ms/downloadazcopy'
        DependsOn = 'Posh-SSH'
    }
    
    # Ugly bootstrap install for azcopy to illustrate 'command' type
    # Thanks to https://github.com/Microsoft/PartsUnlimited/blob/master/env/PartsUnlimited.Environment/PartsUnlimited.Environment/Scripts/Install-AzCopy.ps1
    'AzCopy_Install' = @{
        DependencyType = 'Command'
        Source = '$DepFolder = "$DependencyFolder\Dependencies"',
                 'if(-not (Test-Path $DepFolder\AzCopy\AzCopy.exe)){
                      $null = New-Item $DepFolder\AzCopy -ItemType Directory -Force;
                      Start-Process msiexec -ArgumentList "/a $DepFolder\azcopy.msi /qb TARGETDIR=$DepFolder\AzTemp /quiet" -Wait;
                      Copy-Item "$DepFolder\AzTemp\Microsoft SDKs\Azure\AzCopy\*" $DepFolder\AzCopy -Force;
                      Remove-Item $DepFolder\AZTemp -Recurse -Force;
                 }'
        DependsOn = 'AzCopy_Download'
    }
}
'@
```

We're ready to go! Let's look at the folder before we start:

## Fun With Dependencies

```
PS C:\> dir C:\MyModule -Recurse | Select FullName

FullName                     
--------                     
C:\MyModule\MyModule.psd1    
C:\MyModule\MyModule.psm1    
C:\MyModule\Requirements.psd1 
```

Awesome, so I have a module, and a requirements file that it kicks off on load.  Let's load it up and see what happens!

```
PS C:\> Measure-Command {Import-Module C:\MyModule}

...
Seconds           : 11

PS C:\> Get-ChildItem C:\MyModule\Dependencies -Recurse -Directory -Depth 1 | Select FUllname

FullName                     
--------     
C:\MyModule\Dependencies\AzCopy
C:\MyModule\Dependencies\Posh-SSH
C:\MyModule\Dependencies\PowerShell
C:\MyModule\Dependencies\Posh-SSH\1.7.6
C:\MyModule\Dependencies\PowerShell\.build
C:\MyModule\Dependencies\PowerShell\Images
C:\MyModule\Dependencies\PowerShell\Tests
```

Not bad!  This really depends on bandwidth, I ended up between 11 and 30 seconds for initial runs.  What if we import the module again?

```
PS C:\> Measure-Command {Import-Module C:\MyModule -force}

...
Seconds           : 3

```

That's it!  Every time the module is imported, we see the dependencies and skip their installs.  If we move to another system, the initial launch will pull down our dependencies.

Oh, and to show that we imported those modules, we can run the dummy function from the module that lists their commands:

```
PS C:\Windows\system32> Test-PSDependExample

# Filtered out some output by hand for readability
C:\MyModule\Dependencies\AzCopy
C:\MyModule\Dependencies\Posh-SSH
C:\MyModule\Dependencies\PowerShell
C:\MyModule\Dependencies\azcopy.msi
C:\MyModule\Dependencies\AzCopy\AzCopy.exe
Name                            Path                                                                             
----                            ----                                                                             
MyModule                        C:\MyModule\MyModule.psm1                                                        
Posh-SSH                        C:\Program Files\WindowsPowerShell\Modules\Posh-SSH\1.7.5\Posh-SSH.psd1          
...
```

So!  If you need a re-usable, functional, self-documenting way to pull in module dependencies, and performance isn't a top concern, PSDepend might fit the bill.

Huge thanks to Mike Walker for the idea : )

Cheers!
