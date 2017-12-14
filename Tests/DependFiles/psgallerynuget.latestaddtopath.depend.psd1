@{
    'imaginary' = @{
        DependencyType = 'PSGalleryNuget'
        Version = 'latest'
        Target = 'C:\PSDependPesterTest'
        AddToPath = $True
        Parameters = @{
            Force = $true
        }
    }
}