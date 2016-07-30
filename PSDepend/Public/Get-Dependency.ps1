function Get-Dependency {
    <#
    .SYNOPSIS
        Read a dependency file

    .DESCRIPTION
        Read a dependency file

    .PARAMETER Path
        Path to project root or dependency file.

        If a folder is specified, we search for and process *depends.psd1 files.    
    #>
    [cmdletbinding()]
    param(
        $Path = $PWD.Path
    )

}