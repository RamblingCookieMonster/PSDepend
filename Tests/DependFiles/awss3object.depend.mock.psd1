@{
    Template = @{
        DependencyType = 'AWSS3Object'
        Parameters = @{
            BucketName = 'BucketName'
            Region = 'Region'
            Key='Key'
            SecretKey='SecretKey'
            AccessKey='AccessKey'
        }
        Name='AWSS3Object.mock'
        Target = 'C:\PSDependPesterTest'
    }
}

<#
@{
    'Windows_Single_Server_SharePoint_Foundation.template' = @{
        DependencyType = 'AWSS3Object'
        BucketName = 'cloudformation-templates'
        Region = 'eu-west-1' #Optional
        Key='Windows_Single_Server_SharePoint_Foundation.template'
#        Source = 'https://github.com/RamblingCookieMonster/PSSQLite/blob/master/PSSQLite/x64/System.Data.SQLite.dll?raw=true'
        Target = 'C:\PSDependPesterTest'
    }
}
#>