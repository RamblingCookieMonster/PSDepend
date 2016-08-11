#Get public and private function definition files.
    $Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue )
    $Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
    $ModuleRoot = $PSScriptRoot

#Dot source the files
    Foreach($import in @($Public + $Private))
    {
        Try
        {
            . $import.fullname
        }
        Catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }


#Get nuget dependecy file if we don't have it
    $NuGetPath = Get-Content $ModuleRoot\PSDepend.NugetPath | Where{$_ -notmatch "^\s*#"} | Select -First 1
    $NugetPath = $NugetPath -replace '\$ModuleRoot', $ModuleRoot
    $NuGetPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($NuGetPath)
    BootStrap-Nuget -NugetPath $NuGetPath

Export-ModuleMember -Function $Public.Basename
