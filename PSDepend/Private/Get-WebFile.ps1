# Wrapped for pester mocking...
Function Get-WebFile {
    param($URL, $Path)
    # We have the info, check for file, download it!
    $webclient = New-Object System.Net.WebClient
    $webclient.DownloadFile($URL, $Path)
    $webclient.Dispose()
}