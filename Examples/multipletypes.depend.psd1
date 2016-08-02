@{

    psdeploy = 'latest'

    Not_ExampleNoop = @{
        Name = 'ExampleNoop'
        DependencyType = 'Noop'
        Version = '1.2.5'
        Tags = 'prod', 'test'
        PreScripts = 'C:\RunThisFirst.ps1'
    }

    task = @{
        DependencyType = 'C:\RunThisFirst.ps1'
    }
}