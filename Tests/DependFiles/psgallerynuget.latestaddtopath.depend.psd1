@{
    'imaginary' = @{
        DependencyType = 'PSGalleryNuget'
        Version = 'latest'
        Target = 'TestDrive:/PSDependPesterTest'
        AddToPath = $True
        Parameters = @{
            Force = $true
        }
    }
}
