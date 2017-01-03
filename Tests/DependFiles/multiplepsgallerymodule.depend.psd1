@{
    psdeploy = @{
        DependencyType = 'PSGalleryModule'
        Tags = 'prd', 'tst'
    }
    buildhelpers = @{
        DependencyType = 'PSGalleryModule'
        Tags = 'prd', 'tst'
    }
    pester = @{
        DependencyType = 'PSGalleryModule'
        Tags = 'prd'
    }
}