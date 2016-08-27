# Pester wasn't mocking git... 
# Borrowed idea from https://github.com/pester/Pester/issues/415
function Invoke-ExternalCommand {
    [cmdletbinding()]
    param($Command, [string[]]$Arguments)

    $result = $null
    $result = & $command @arguments  
    Write-Verbose "$($result | Out-String)"
}