@{
    Template1 = @{
        DependencyType = 'AWSS3Object'
        #https://s3-eu-west-1.amazonaws.com/cloudformation-templates-eu-west-1/Windows_Single_Server_SharePoint_Foundation.template
        Parameters = @{
            BucketName = 'cloudformation-templates-eu-west-1'
            Region = 'eu-west-1'
            Key='Windows_Single_Server_SharePoint_Foundation.template'
        }
        Name='Windows_Single_Server_SharePoint_Foundation.template.changed'
        Target = 'C:\PSDependPesterTest'
    }
    Template2 = @{
        DependencyType = 'AWSS3Object'
        #https://s3-eu-west-1.amazonaws.com/cloudformation-templates-eu-west-1/Windows_Single_Server_SharePoint_Foundation.template
        Parameters = @{
            BucketName = 'cloudformation-templates-eu-west-1'
            Region = 'eu-west-1'
            Key='Windows_Single_Server_SharePoint_Foundation.template'
        }
        Target = 'C:\PSDependPesterTest'
    }
}