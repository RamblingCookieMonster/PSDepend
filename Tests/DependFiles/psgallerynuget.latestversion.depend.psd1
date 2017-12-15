@{
    'jenkins' = @{
        DependencyType = 'PSGalleryNuget'
        Version = 'latest'
        Target = 'C:\PSDependPesterTest'
        Parameters = @{
            Force = $true
        }
    }
}