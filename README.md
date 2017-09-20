[![Build status](https://ci.appveyor.com/api/projects/status/4mwhsx9pkfpc1j48/branch/master?svg=true)](https://ci.appveyor.com/project/RamblingCookieMonster/psdepend/branch/master)

PSDepend
========

This is a simple PowerShell dependency handler.  You might loosely compare it to `bundle install` in the Ruby world or `pip install -r requirements.txt` in the Python world.

PSDepend allows you to write simple requirements.psd1 files that describe what dependencies you need, which you can invoke with `Invoke-PSDepend`

**WARNING**:

* Minimal testing.  This is in my backlog, but PRs would be welcome!
* This borrows quite heavily from PSDeploy.  There may be leftover components that haven't been adapted, have been improperly adapted, or shouldn't have been adapted
* Would love ideas, feedback, pull requests, etc., but if you rely on this, consider pinning a specific version to avoid hitting breaking changes.

## Getting Started

### Installing PSDepend

```powershell
# PowerShell 5
Install-Module PSDepend

# PowerShell 3 or 4, curl|bash bootstrap. Read before running something like this : )
iex (new-object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/RamblingCookieMonster/PSDepend/master/Examples/Install-PSDepend.ps1')

# Git
    # Download the repository
    # Unblock the zip
    # Extract the PSDepend folder to a module path (e.g. $env:USERPROFILE\Documents\WindowsPowerShell\Modules\)

# Import and start exploring
Import-Module PSDepend
Get-Command -Module PSDepend
Get-Help about_PSDepend
```

### Example Scenarios

In-depth:

* [Creating a virtual-environment-light](/Examples/VirtualEnvironment.md)
* [Handling module dependencies](/Examples/ModuleDependencies.md)

Recipes:

* [How Do I...](/Examples/HowDoI.md)

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
RamblingCookieMonster/PowerShell GitHub          master
PSDeploy                         PSGalleryModule 0.1.21
```

We can indicate the dependency type more explicitly if desired:

```powershell
@{
    'PSGalleryModule::InvokeBuild' = 'latest'
    'GitHub::RamblingCookieMonster/PSNeo4j' = 'master'
}
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

Note that we replace certain strings in Target and Source fields:

* $PWD (or .) refer to the current path
* $ENV:USERPROFILE, $ENV:TEMP, $ENV:ProgramData, $ENV:APPDATA
* Variables need to be in single quotes or the $ needs to be escaped.  We replace the raw strings with the values for you. This will not work: Target = "$PWD\dependencies".  This will: Target = '$PWD\dependencies'
* If you call Invoke-PSDepend -Target $Something, we override any value for target
* Thanks to Mike Walker for the idea!

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

## Extending PSDepend

PSDepend is extensible.  To create a new dependency type:

* Pick a name.  We'll use `Nothing` as an example
* Create `DependencyType.ps1` (substituting in your name, e.g. `Nothing.ps1`) in the [PSDependScripts folder](https://github.com/RamblingCookieMonster/PSDepend/tree/master/PSDepend/PSDependScripts)
* Your `DependencyType.ps1` (`Nothing.ps1` in this example) should...
  * Have comment based help
  * Include details on how you use Dependency metadata.  For example, in [Git.ps1](https://github.com/RamblingCookieMonster/PSDepend/blob/master/PSDepend/PSDependScripts/Git.ps1), `Version` is used in git checkout
  * Include a PSDependAction parameter that takes `Install`, `Test`, `Import`, or a subset of these.  [Example parameter declaration](https://github.com/RamblingCookieMonster/PSDepend/blob/master/PSDepend/PSDependScripts/PSGalleryModule.ps1#L40)
  * Depending on which PSDependAction is specified by the user, your script should `install`, `test` (return true or false depending on whether the dependency exists - sometimes this is impossible to check), and `import` (import the dependency - if appropriate, this might import a module or dot source code, for example)
* Add your new dependency type to [PSDependMap.psd1](https://github.com/RamblingCookieMonster/PSDepend/blob/master/PSDepend/PSDependMap.psd1)

So!  In our example, we would create `PSDepend\PSDependScripts\Nothing.ps1`, with the following code:

```powershell
<#
    .SYNOPSIS
        Example Dependency

    .DESCRIPTION
        Example Dependency

        Relevant Dependency metadata:
            Version: Used for nonsense output

    .PARAMETER Dependency
        Dependency to process

    .PARAMETER StringParameter
        An example parameter that does nothing

    .PARAMETER PSDependAction
        Test, Install, or Import the dependency.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency
        Import: Import the dependency
#>
[cmdletbinding()]
param (
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]$Dependency,

    [ValidateSet('Test', 'Install', 'Import')]
    [string[]]$PSDependAction = @('Install'),

    [string]$StringParameter
)

$Output = [PSCustomobject]@{
    DependencyName = $Dependency.DependencyName
    Status = "Invoking $PSDependAction action"
    BoundParameters = $PSBoundParameters.Keys
    Message = "Version [$Version]"
}

# Notice that we end the script if we're testing.
if( $PSDependAction -Contains 'Test' )
{
    Write-Verbose $Output
    return $true
}

$Output
```

Finally, we'll add an entry to `PSDependMap.psd1`:

```powershell
    Nothing = @{
        Script= 'Nothing.ps1'
        Description = 'Example dependency'
    }
```

Lastly, we'll define a requirements.psd1 using this dependency:

```powershell
@{
    ExampleDependency = @{
        DependencyType = 'Nothing'
        Version = 1
        Parameters = @{
            StringParameter = 'A thing'
        }
    }
}
```

Finally, run it!

```powershell
Invoke-PSDepend -Path C:\requirements.psd1 -Test -Quiet
```

`True`

```powershell
Invoke-PSDepend -Path C:\requirements.psd1
```

```
DependencyName    Status                  BoundParameters                               Message
--------------    ------                  ---------------                               -------
ExampleDependency Invoking Install action {StringParameter, PSDependAction, Dependency} Version [1]
```

```powershell
Invoke-PSDepend -Path C:\requirements.psd1 -Import
```

```
DependencyName    Status                 BoundParameters                               Message
--------------    ------                 ---------------                               -------
ExampleDependency Invoking Import action {StringParameter, PSDependAction, Dependency} Version [1]
```




## Notes

Major props to Michael Willis for the idea - check out his [PSRequire](https://github.com/Xainey/PSRequire), a similar but more feature-full solution.
