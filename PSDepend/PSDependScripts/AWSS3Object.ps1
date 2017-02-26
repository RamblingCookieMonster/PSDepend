#requires -modules AWSPowerShell
<#
    .SYNOPSIS
        Download a file from AWS S3 bucket

    .DESCRIPTION
        Download a file from AWS S3 bucket

        Relevant Dependency metadata:
            DependencyName (Key): The key for this dependency is used as the URL. This can be overridden by 'Source'
            Name: Optional file name for the downloaded file.  Defaults to parsing filename from the URL
            Target: The folder to download this file to.  If a full path to a new file is used, this overrides any other file name.
            Source: Optional override for URL
            AddToPath: If specified, prepend the target's parent container to PATH

    .PARAMETER PSDependAction
        Test or Install the module.  Defaults to Install

        Test: Return true or false on whether the dependency is in place
        Install: Install the dependency

    .PARAMETER BucketName
        The S3 bucket name

    .PARAMETER Region
        The AWS region

    .PARAMETER Key
        The S3 bucket's key

    .PARAMETER SecretKey
        The secret key

    .PARAMETER AccessKey
        The access key

    .EXAMPLE
        Template = @{
            DependencyType = 'AWSS3Object'
            #https://s3-eu-west-1.amazonaws.com/cloudformation-templates-eu-west-1/Windows_Single_Server_SharePoint_Foundation.template
            Parameters = @{
                BucketName = 'cloudformation-templates-eu-west-1'
                Region = 'eu-west-1'
                Key='Windows_Single_Server_SharePoint_Foundation.template'
            }
            Name='Windows_Single_Server_SharePoint_Foundation.template.changed'
            Target = 'C:\Temp'
        }

        # Downloads Windows_Single_Server_SharePoint_Foundation.template to C:\temp\Windows_Single_Server_SharePoint_Foundation.template.changed

    .EXAMPLE
        Template = @{
            DependencyType = 'AWSS3Object'
            #https://s3-eu-west-1.amazonaws.com/cloudformation-templates-eu-west-1/Windows_Single_Server_SharePoint_Foundation.template
            Parameters = @{
                BucketName = 'cloudformation-templates-eu-west-1'
                Region = 'eu-west-1'
                Key='Windows_Single_Server_SharePoint_Foundation.template'
            }
            Target = 'C:\Temp'
        }

        # Downloads Windows_Single_Server_SharePoint_Foundation.template to C:\temp\Windows_Single_Server_SharePoint_Foundation.template
#>
[cmdletbinding()]
param(
    [PSTypeName('PSDepend.Dependency')]
    [psobject[]]
    $Dependency,

    [ValidateSet('Test', 'Install')]
    [string[]]$PSDependAction = @('Install'),

    [Parameter(Mandatory=$false)]
    [string]$BucketName,

    [Parameter(Mandatory=$false)]
    [string]$Region,

    [Parameter(Mandatory=$false)]
    [string]$Key,

    [Parameter(Mandatory=$false)]
    [string]$SecretKey,

    [Parameter(Mandatory=$false)]
    [string]$AccessKey
)

# Extract data from Dependency
$DependencyName = $Dependency.DependencyName
$Target = $Dependency.Target
$Name = $Dependency.Name

# Decide if the configuration controls the name of the file to download
$UseLocalFile=$Name -ne $null
if(-not $UseLocalFile)
{
    # The name of the file on S3 becomes the file
    $Name=$Key
}
$TargetPath=Join-Path $Target ($Name.Replace("/","\"))
$TargetPathExists=Test-Path -Path $TargetPath

if($PSDependAction -contains 'Test')
{
    $TargetPathExists
}

if($PSDependAction -contains 'Install')
{
    if($TargetPathExists)
    {
        Write-Verbose "Skipping existing file [$Name] in [$Target]"
    }
    else
    {
        if($UseLocalFile)
        {
            Copy-S3ObjectWrap -BucketName $BucketName -Key $Key -LocalFile $TargetPath -Region $Region -AccessKey $AccessKey -SecretKey $SecretKey
        }
        else
        {
            Copy-S3ObjectWrap -BucketName $BucketName -Key $Key -LocalFolder $Target -Region $Region -AccessKey $AccessKey -SecretKey $SecretKey
        }
    }    
}

if($Dependency.AddToPath)
{   
    Write-Verbose "Setting PATH to`n$($PathToAdd, $env:PATH -join ';' | Out-String)"
    Add-ToItemCollection -Reference Env:\Path -Item $PathToAdd
}
