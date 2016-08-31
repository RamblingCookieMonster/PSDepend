[![Build status](https://ci.appveyor.com/api/projects/status/4mwhsx9pkfpc1j48/branch/master?svg=true)](https://ci.appveyor.com/project/RamblingCookieMonster/psdepend/branch/master)

PSDepend
========

This is a simple PowerShell dependency handler.  You might loosely compare it to `bundle install` in the Ruby world or `pip install -r requirements.txt` in the Python world.

PSDepend allows you to write simple requirements.psd1 files that describe what dependencies you need, which you can invoke with `Invoke-PSDepend`

**WARNING**:

* Opening this up quite early to get feedback and direction.  There will be breaking changes without notice until we hit version 0.1.0
* Minimal to no testing.  This is in my backlog, but PRs would be welcome!
* This borrows quite heavily from PSDeploy.  There may be leftover components that haven't been adapted, have been improperly adapted, or shouldn't have been adapted
* Would love ideas, feedback, pull requests, etc., but if you rely on this, consider pinning a specific version to avoid hitting breaking changes.

## Getting Started

### Installing PSDepend

```powershell
# PowerShell 5
Install-Module PSDepend

# PowerShell 3 or 4, curl|bash bootstrap. Read before running something like this : )
iex (new-object System.Net.WebClient).DownloadString('https://raw.github.com/ramblingcookiemonster/PSDepend/Examples/Install-PSDepend.ps1')

# Git
    # Download the repository
    # Unblock the zip
    # Extract the PSDepend folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

# Import and start exploring
Import-Module PSDepend
Get-Command -Module PSDepend
Get-Help about_PSDepend
```

### Example

This is a quick demo illustrating a "virtual-environment-light" scenario.

We pull down some dependencies and import them directly, regardless of whether we have different versions elsewhere on the system

```powershell
# TLDR: This looks long, but that's mostly for your benefit.
#       Here's the important bit, assuming you have a requirements.psd1 in place:
Invoke-PSDepend -Path C:\ProjectX -Install -Import -Force


# Set up a project folder, and a requirements.psd1
dir C:\Proj*
mkdir C:\ProjectX -force
Set-Content C:\ProjectX\Requirements.psd1 -Value @'
@{
    PSDependOptions = @{
        Target = 'C:\ProjectX' # I want all my dependencies installed here
        Parameters = @{
            Force = $True      # I want to use -Force on each dependency
        }
    }

    # Grab some modules
    PSSlack = 'latest'
    ImportExcel = 'latest'
    'Posh-SSH' = 'latest'

    # Clone a git repo
    'ramblingcookiemonster/PowerShell' = 'master'

    # Download a file
    'psrabbitmq.dll' = @{
        DependencyType = 'FileDownload'
        Source = 'https://github.com/RamblingCookieMonster/PSRabbitMq/raw/master/PSRabbitMq/lib/RabbitMQ.Client.dll'
    }
}
'@

Import-Module PSDepend

# Do I have my dependencies already? Nope
Invoke-PSDepend -Path C:\ProjectX -Test | Select Dependency*
<#
    DependencyFile                DependencyName                   DependencyType  DependencyExists
    --------------                --------------                   --------------  ----------------
    C:\ProjectX\Requirements.psd1 ImportExcel                      PSGalleryModule            False
    C:\ProjectX\Requirements.psd1 Posh-SSH                         PSGalleryModule            False
    C:\ProjectX\Requirements.psd1 PSSlack                          PSGalleryModule            False
    C:\ProjectX\Requirements.psd1 ramblingcookiemonster/PowerShell Git                        False
    C:\ProjectX\Requirements.psd1 psrabbitmq.dll                   FileDownload               False
#>

# Install them...
Invoke-PSDepend -Path C:\ProjectX -Force

# Test again, this time just get a true or false:
Invoke-PSDepend -Path C:\ProjectX -Test -Quiet
# True

# Just to be sure...
dir C:\ProjectX
<#  Yep!
    Mode                LastWriteTime         Length Name                                                                                                        
    ----                -------------         ------ ----                                                                                                        
    d-----        8/30/2016  10:48 AM                ImportExcel                                                                                                 
    d-----        8/30/2016  10:48 AM                Posh-SSH                                                                                                    
    d-----        8/30/2016  10:48 AM                PowerShell                                                                                                  
    d-----        8/30/2016  10:48 AM                PSSlack                                                                                                     
    -a----        8/30/2016  10:48 AM         248320 RabbitMQ.Client.dll                                                                                         
    -a----        8/30/2016  10:48 AM            627 Requirements.psd1  
#>

# Oh, let's import them
Invoke-PSDepend -Path C:\ProjectX -Import

# Did they import?
Get-Module PSSlack, ImportExcel, Posh-SSH | Select Name, Path
<#
    Name        Path                                          
    ----        ----                                          
    ImportExcel C:\ProjectX\ImportExcel\2.2.7\ImportExcel.psm1
    Posh-SSH    C:\ProjectX\Posh-SSH\1.7.6\Posh-SSH.psd1      
    PSSlack     C:\ProjectX\PSSlack\0.0.15\PSSlack.psm1 
#>
```

## Defining Dependencies

Store dependencies in a PowerShell data file, and use *.depend.psd1 or requirements.psd1 to allow Invoke-PSDepend to find your files for you.

What does a dependency file look like?

### Simple syntax

Here's the simplest syntax.  If this meets your needs, you can stop here:

```powershell
@{
    psake        = 'latest'
    Pester       = 'latest'
    BuildHelpers = '0.0.20'  # I don't trust this Warren guy...
    PSDeploy     = '0.1.21'  # Maybe pin the version in case he breaks this...
    
    RamblingCookieMonster/PowerShell = 'master'
}
```

And what PSDepend sees:

```
DependencyName                   DependencyType  Version Tags
--------------                   --------------  ------- ----
psake                            PSGalleryModule latest      
BuildHelpers                     PSGalleryModule 0.0.20      
Pester                           PSGalleryModule latest      
RamblingCookieMonster/PowerShell Git             master      
PSDeploy                         PSGalleryModule 0.1.21   
```

There's a bit more behind the scenes - we assume you want PSGalleryModules or GitHub repos unless you specify otherwise, and we hide a few dependency properties.

### Flexible syntax

What else can we put in a dependency?  Here's an example using a more flexible syntax.  You can mix and match.

```powershell
@{
    psdeploy = 'latest'

    buildhelpers_0_0_20 = @{
        Name = 'buildhelpers'
        DependencyType = 'PSGalleryModule'
        Parameters = @{
            Repository = 'PSGallery'
        }
        Version = '0.0.20'
        Tags = 'prod', 'test'
        PreScripts = 'C:\RunThisFirst.ps1'
        DependsOn = 'some_task'
    }

    some_task = @{
        DependencyType = 'task'
        Target = 'C:\RunThisFirst.ps1'
        DependsOn = 'nuget'
    }

    nuget = @{
        DependencyType = 'FileDownload'
        Source = 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe'
        Target = 'C:\nuget.exe'
    }  
}
```

This example illustrates using a few different dependency types, using DependsOn to sort things (e.g. some_task runs after nuget), tags, and other options.

You can inspect the full output as needed.  For example:

```powershell
# List the dependencies, get the third item, show all props
$Dependency = Get-Dependency \\Path\To\complex.depend.ps1
$Dependency[2] | Select *
```

```
DependencyFile : \\Path\To\complex.depend.psd1
DependencyName : buildhelpers_0_0_20
DependencyType : PSGalleryModule
Name           : buildhelpers
Version        : 0.0.20
Parameters     : {Repository}
Source         : 
Target         : 
AddToPath      : 
Tags           : {prod, test}
DependsOn      : some_task
PreScripts     : C:\RunThisFirst.ps1
PostScripts    : 
Raw            : {Version, Name, Tags, DependsOn...}
```

## Exploring and Getting Help

Each DependencyType - PSGalleryModule, FileDownload, Task, etc. - might treat these standard properties differently, and may include their own Parameters.  For example, in the BuildHelpers node above, we specified a Repository parameter.

How do we find out what these mean?  First things first, let's look at what DependencyTypes we have available:

```powershell
Get-PSDependType
```

```
DependencyType  Description                                                 DependencyScript                                    
--------------  -----------                                                 ----------------                                    
PSGalleryModule Install a PowerShell module from the PowerShell Gallery.    C:\...\PSDepend\PSDepen...
Task            Support dependencies by handling simple tasks.              C:\...\PSDepend\PSDepen...
Noop            Display parameters that a depends script would receive...   C:\...\PSDepend\PSDepen...
FileDownload    Download a file                                             C:\...\PSDepend\PSDepen...
```

Now that we know what types are available, we can read the comment-based help.  Hopefully the author took their time to write this:

```PowerShell
Get-PSDependType -DependencyType PSGalleryModule -ShowHelp
```

```
...
DESCRIPTION
    Installs a module from a PowerShell repository like the PowerShell Gallery.

    Relevant Dependency metadata:
        Name: The name for this module
        Version: Used to identify existing installs meeting this criteria, and as RequiredVersion for installation.  Defaults to 'latest'
        Target: Used as 'Scope' for Install-Module.  If this is a path, we use Save-Module with this path.  Defaults to 'AllUsers'

PARAMETERS
...
    -Repository <String>
        PSRepository to download from.  Defaults to PSGallery
```

In this example, we see how PSGalleryModule treats the Name, Version, and Target in a depend.psd1, and we see a Parameter specific to this DependencyType, 'Repository'

Finally, we have a few about topics, and individual commands have built in help:

```
Get-Help about_PSDepend
Get-Help about_PSDepend_Definitions
Get-Help Get-Dependency -Full
```

## Notes

Major props to Michael Willis for the idea - check out his [PSRequire](https://github.com/Xainey/PSRequire), a similar but more feature-full solution.
