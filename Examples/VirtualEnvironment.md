# Creating a Virtual Environment of Sorts

This is a quick demo illustrating a "virtual-environment-light" scenario.

We pull down some dependencies and import them directly, regardless of whether we have different versions elsewhere on the system

## Set Up A Demo "Project"

```powershell
# Set up a project folder, and a requirements.psd1
mkdir C:\ProjectX -force
Set-Content C:\ProjectX\Requirements.psd1 -Value @'
@{
    PSDependOptions = @{
        Target = '$DependencyFolder' # I want all my dependencies installed here
        AddToPath = $True            # I want to prepend project to $ENV:Path and $ENV:PSModulePath
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
```

We're ready to go!

## Test and Create the Virtual Environment

```powershell
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
Invoke-PSDepend -Path C:\ProjectX\requirements.psd1 -Test -Quiet
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
Invoke-PSDepend -Path C:\ProjectX\requirements.psd1 -Import -Force

# Did they import?
Get-Module PSSlack, ImportExcel, Posh-SSH | Select Name, Path
<#
    Name        Path                                          
    ----        ----                                          
    ImportExcel C:\ProjectX\ImportExcel\2.2.7\ImportExcel.psm1
    Posh-SSH    C:\ProjectX\Posh-SSH\1.7.6\Posh-SSH.psd1      
    PSSlack     C:\ProjectX\PSSlack\0.0.15\PSSlack.psm1 
#>


# Lastly, did our PSModulePath and Path get updated?
$env:Path -split ';'

<#
    C:\ProjectX
    C:\Windows\system32
    ...
#>

$env:PSModulePath -split ';'

<#
    C:\ProjectX
    C:\Users\wframe\Documents\WindowsPowerShell\Modules
#>
```

That's about it!  You could use code similar to this to set up a virtual environment of sorts, with certain modules pre-loaded, and certain paths and psmodulepaths taking precedence for the current session.

Yes, I know this isn't really a virtual environment, just seemed like the quickest way to get the idea across : )