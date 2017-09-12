# Wrapped for pester mocking...
Function Copy-S3ObjectWrap {
    param($BucketName, $Key, $LocalFolder, $LocalFile, $Region, $AccessKey, $SecretKey)
    if($LocalFile)
    {
        Copy-S3Object -BucketName $BucketName -Key $Key -LocalFile $LocalFile -Region $Region -AccessKey $AccessKey -SecretKey $SecretKey
    }
    else
    {
        Copy-S3Object -BucketName $BucketName -Key $Key -LocalFolder $LocalFolder -Region $Region -AccessKey $AccessKey -SecretKey $SecretKey
    }

}