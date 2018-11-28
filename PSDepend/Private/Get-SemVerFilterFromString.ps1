function Get-SemVerFilterFromString
{
    [cmdletBinding()]
    [OutputType([ScriptBlock])]
    Param(
        [Parameter(Mandatory)]
        [string]$Filter
    )
    # Let the Parser tokenize the string filter for us
    $FilterSB = [Scriptblock]::Create($Filter)

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

    $allTokens = $FilterSB.Ast.FindAll( {$true},$true).Where{
        $_ -is [System.Management.Automation.Language.ConstantExpressionAst] -or
        $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
        $_ -is [System.Management.Automation.Language.ParameterAst] -or
        $_ -is [System.Management.Automation.Language.CommandParameterAst]
    }

    $offset = 0
    foreach( $extent in $allTokens.extent)
    {
        if($extent.Text -in @('-gt','-ge','-lt','-le','-eq','-ne'))
        {
            $replaceWith = &$ConvertExpr $extent.text
        }
        elseif($extent.Text -in @('-or','-and'))
        {
            $replaceWith = "$($extent.text)"
        }
        else
        {
            $replaceWith = "'$($extent.text)'))"
        }

        $addOffset = $replaceWith.length - $extent.Text.Length
        $Filter = $Filter.Remove(($extent.StartOffset + $offset), ($extent.Text.Length))
        $Filter = $Filter.Insert(($extent.StartOffset + $offset),$replaceWith)
        $offset += $addOffset
    }
    Write-Debug -Message $Filter
    [scriptblock]::Create($Filter)
}