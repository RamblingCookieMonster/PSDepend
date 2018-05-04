@{
    'imaginary' = @{
        DependencyType = 'PSGalleryNuget'
        Version = '1.2.5'
        Target = 'TestDrive:/PSDependPesterTest'
        AddToPath = $True
        Parameters = @{
            Force = $true
        }
    }
}
