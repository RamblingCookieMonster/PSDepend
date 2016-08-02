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