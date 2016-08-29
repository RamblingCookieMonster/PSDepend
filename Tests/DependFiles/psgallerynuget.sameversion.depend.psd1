@{
    'jenkins' = @{
        DependencyType = 'PSGalleryNuget'
        Version = '1.2.5'
        Target = 'C:\PSDependPesterTest'
        Parameters = @{
            Force = $true
        }
    }
}