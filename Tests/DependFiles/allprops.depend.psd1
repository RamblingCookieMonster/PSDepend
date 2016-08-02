@{
    DependencyName = @{
        Name = 'Name'
        DependencyType = 'noop'
        Parameters = @{
            Random = 'Value'
        }
        Version = 'Version'
        Tags = 'tag', 'tags'
        PreScripts = 'C:\PreScripts.ps1'
        PostScripts = 'C:\PostScripts.ps1'
        DependsOn = 'DependsOn'
        AddToPath = $True
        Source = 'Source'
        Target = 'Target'
        ExtendedSchema = @{
            IsTotally = 'Captured'
        }
    }
}