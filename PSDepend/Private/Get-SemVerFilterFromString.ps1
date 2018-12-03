function Get-SemVerFilterFromString
{
    [cmdletBinding()]
    [OutputType([ScriptBlock])]
    Param(
        [Parameter(Mandatory)]
        [string]$Filter
    )
    # Let the Parser tokenize the string filter for us
    $FilterString = $Filter
    $Tokens = $null
    $ParseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Filter,[ref]$Tokens,[ref]$ParseErrors)

    $ConvertExpr = { # Converter of operator into first part of comparison statement
        Switch($Args[0])
        {
            '-gt'
            {
                '(">".GetEnumerator()  -contains (Compare-SemVerVersion $_.Version'
            }
            '-ge'
            {
                '(">=".GetEnumerator() -contains (Compare-SemVerVersion $_.Version'
            }
            '-lt'
            {
                '("<".GetEnumerator()  -contains (Compare-SemVerVersion $_.Version'
            }
            '-le'
            {
                '("<=".GetEnumerator() -contains (Compare-SemVerVersion $_.Version'
            }
            '-eq'
            {
                '("=".GetEnumerator()  -contains (Compare-SemVerVersion $_.Version'
            }
            '-ne'
            {
                '(($_.Version -ne'
            }
        }
    }

    $FilterToken = [System.Collections.ArrayList]::new()
    foreach ($token in $tokens) {
        switch -Regex ($token.text.Trim())
        {
            '-(lt|le|gt|ge|eq|ne)'
            {
                $null = $FilterToken.add((&$ConvertExpr $_))
            }
            "^(\`"|\')?\d+[\.\d]+(-.*)*(\+.*)*(\`"|\')?$"
            {
                $version = $_ -replace "^(\`"|\')",'' -replace "(\`"|\')?$"
                $null = $FilterToken.add(("'"+$version+"'))"))
            }
            default
            {
                $null = $FilterToken.Add($_)
            }
        }
    }
    $NewFilter = ($FilterToken -join ' ').Trim()


    Write-Debug -Message $NewFilter
    try {
        [scriptblock]::Create($NewFilter)
    }
    catch {
        Throw "Could not parse '$FilterString'."
    }
}